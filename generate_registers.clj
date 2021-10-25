(ns generate-registers
  (:require [clojure.core.match :refer [match]]
            [clojure.string :as str]
            [clojure.java.shell :as sh]
            [lonocloud.synthread :as ->]
            [clojure.xml :as xml]
            [clojure.zip :as zip :refer [up down right left node]]
            [clojure.data.zip.xml :refer [xml-> xml1-> attr= text=]]))

;;;;;;;;;;;;
;;TODO:
;;handle register clusters
;;compare w/ https://github.com/kvasir-io/Kvasir

(defn hex->int
  [s]
  (Long/parseLong (str/replace s #"^0(x|X)" "") 16))


;;SVD format description:
;;https://www.keil.com/pack/doc/CMSIS/SVD/html/svd_Format_pg.html
;;https://www.keil.com/pack/doc/CMSIS/SVD/html/schema_1_2_gr.html


(def default-register-size-bits
  32)


;;;;;;;;;;;;;;;;;;;;

(defn select-children-tag-content
  [loc tag-names]
  (into {} (for [t tag-names]
             (when-let [loc (xml1-> loc t)]
               [t (first (:content (node loc)))]))))


(defn enums-by-usage
  [field-loc usage]
  (seq (for [e (xml-> field-loc
                      :enumeratedValues
                      (if usage
                        #(not (empty? (xml-> % :usage (text= usage))))
                        #(empty? (xml-> % :usage)))
                      :enumeratedValue)]
         (-> (select-children-tag-content e [:name :description :value])
             (update :value (fn [s]
                              (if (re-find #"^0(x|X)" s)
                                s
                                (Integer/parseInt s))))))))


(defn ->comment
  [s]
  (str/replace s #"(?m)^\s*" "///"))


(defn ->identifier
  [s]
  (-> s
      ;;zig legal identifiers
      (str/replace "[%s]" "")
      (str/replace "%s" "")
      (str/replace #"^([0-9])" "_$1")

      ;;zig reserved words
      (str/replace #"(?i)^(fn|error|break|suspend|resume|align|or)$" "_$1")

      ;;camel case to underscores
      (str/replace #"([a-z])([A-Z])" "$1_$2")
      str/lower-case))


(defn field-reset
  [register-reset register-size-bits lsb msb]
  (->
   ;;clear extra high bits
   (reduce (fn [x idx]
             (bit-clear x idx))
           register-reset
           (range (inc msb) register-size-bits))
   ;;then shift all the way right
   (bit-shift-right lsb)))


(defn print-fields-zig
  [fields register-size-bits register-reset-value type-name k-enum]
  (println "const" type-name " =" "packed struct {")
  (loop [fields (sort-by :lsb fields)
         bit-offset 0]

    (if-let [{:keys [name description lsb msb] :as field} (first fields)]
      (do
        (when (not= lsb bit-offset)
          ;;add padding
          ;;TODO: default value for padding based on register reset value
          (println (str "_unused" bit-offset) ":" (str "u" (- lsb bit-offset)) " = 0,"))

        ;;comment
        (println (->comment (str name " [" lsb ":" msb "]")))
        (println (->comment description))

        ;;emit anon struct of values or raw integer for field.
        ;;both must have defaults so the user doesn't need to specify all fields every time they write to a register
        (let [default-value (or (some-> register-reset-value
                                        (field-reset register-size-bits lsb msb))
                                0)]

          (if-let [enums (k-enum field)]
            (let [default-enum (first (filter #(= default-value (:value %)) enums))]
              (do
                (println (->identifier name) ":" "packed enum(" (str "u" (inc (- msb lsb))) ")")
                (println "{")

                (doseq [{:keys [name description value]} enums]
                  (println (->comment description))
                  (println (->identifier name) "=" value ","))

                (when-not default-enum
                  (println "_zero = 0,"))

                (println "}")
                ;;default enum value for this field
                (println "=" (if default-enum
                               (str "." (->identifier (:name default-enum)))
                               "._zero"))))


            ;;if not enum, then just a raw integer field
            (do
              (println (->identifier name) ":" (str "u" (inc (- msb lsb))))
              (println "=" default-value))))

        (println ",")

        (recur (rest fields)
               (inc msb)))

      ;;after we've added all fields, add padding if necessary
      (when (not= bit-offset register-size-bits)
        (println (str "_unused" bit-offset) ":" (str "u" (- register-size-bits bit-offset)) " = 0,"))))

  (println "};"))


(defn peripheral->zig
  [p]
  (with-out-str
    (let [{:keys [name description baseAddress registers]} p]
      (println (->comment description))
      (println "pub const" (->identifier name) "= struct{")

      (doseq [{:keys [name description addressOffset resetValue access fields dim dimIncrement] :as register} registers]

        (let [register-name (->identifier name)
              type-name (str register-name "_val")
              separate-read-write-types? (not (empty? (mapcat :enums-read fields)))
              register-size-bits (match [(some-> dimIncrement
                                                 hex->int)]
                                   [nil] default-register-size-bits
                                   ;;why some manufacturers specify dimIncrement 0 is beyond me
                                   [0]   default-register-size-bits
                                   [increment] (* 8 increment))
              register-reset-value (some-> resetValue
                                           hex->int)]

          (println "")
          (println "")
          (println "//////////////////////////")
          (println (->comment name))

          ;;;;;;;;;;;;;;
          ;;Type

          ;;TODO: how to handle resetValue?
          (if separate-read-write-types?
            (do
              (print-fields-zig fields register-size-bits register-reset-value (str type-name "_read") :enums-read)
              (print-fields-zig fields register-size-bits register-reset-value (str type-name "_write") :enums-write))
            (print-fields-zig fields register-size-bits register-reset-value type-name :enums))

          ;;;;;;;;;;;;;;
          ;;Register

          (println (->comment description))
          (println "pub const" register-name "="

                   (cond
                     ;;TODO: need better error messages when one tries to call write on a read-only register.
                     (= access "read-only")
                     (str "RegisterRW(" type-name ",void"  ")")

                     (= access "write-only")
                     (str "RegisterRW(" "void, " type-name ")")

                     (and (= access "read-write") separate-read-write-types?)
                     (str "RegisterRW(" type-name "_read, " type-name "_write)")

                     (and (= access "read-write") (not separate-read-write-types?))
                     (str "Register(" type-name ")"))

                   (if (and dim dimIncrement)
                     (let [dim (hex->int dim)
                           dimIncrement (hex->int dimIncrement)]
                       ;;array of registers
                       (str ".initRange(" baseAddress "+" addressOffset "," dimIncrement "," dim ");"))
                     ;;single register
                     (str ".init(" baseAddress "+" addressOffset ");")))))

      (println "};"))))


(defn normalize-bit-fields
  [field]
  (match [field]

    [{:msb msb :lsb lsb}]
    (-> field
        (update :lsb #(Integer/parseInt %))
        (update :msb #(Integer/parseInt %)))

    [{:bitOffset bo :bitWidth bw}]
    (let [offset (Integer/parseInt bo)
          width (Integer/parseInt bw)]

      (assoc field
             :lsb offset
             :msb (dec (+ offset width))))))


(defn expand-derivations
  "Given collection of maps, merges based on :derivedFrom references to other maps :name"
  [xs]
  (let [by-name (into {} (for [x xs]
                           [(:name x) x]))
        expanded (for [x xs]

                   (if-let [parent (-> x :derivedFrom by-name)]
                     (-> parent
                         (merge x)
                         (dissoc :derivedFrom))
                     x))]

    (binding [*out* *err*]
      (doseq [x expanded]
        (when (:derivedFrom x)
          (println "Could not derive" (:name x)))))

    expanded))


(defn peripheral-registers
  [raw-peripheral]
  (seq (for [r (xml-> raw-peripheral :registers :register)]
         (merge (select-children-tag-content r [:name :description :addressOffset :access :resetValue
                                                ;;arrays
                                                :dim :dimIncrement])
                (let [fields (for [f (xml-> r :fields :field)]
                               ;;TODO: field <writeConstraint>
                               (-> (select-children-tag-content f [:name :description :lsb :msb :bitOffset :bitWidth])
                                   normalize-bit-fields
                                   (merge
                                    (:attrs (node f))
                                    {:enums-read (enums-by-usage f "read")
                                     :enums-write (enums-by-usage f "write")
                                     :enums (or (enums-by-usage f "read-write")
                                                (enums-by-usage f nil))})))]
                  ;;TODO: expand derivations for enums; see `<enumeratedValues derivedFrom="DMAEN" />` in stm32f0
                  {:fields (expand-derivations fields)})))))


(defn svd->peripherals
  [svd]
  (let [raw-peripherals (xml-> svd
                               :device
                               :peripherals
                               :peripheral)
        peripherals (->> raw-peripherals
                         (map (fn [p]
                                (merge (select-children-tag-content p [:name :description :baseAddress :groupName])
                                       (:attrs (node p))
                                       (when-let [registers (peripheral-registers p)]
                                         {:registers registers})))))]

    (expand-derivations peripherals)))


(defn svd->zig
  [svd]
  (with-out-str
    (println (slurp "registers.zig"))
    (doseq [p (svd->peripherals svd)]
      (println (peripheral->zig p)))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; "main"

(doseq [f (file-seq (java.io.File. "vendor"))]
  (when (re-matches #".*\.svd(\.patched)?"  (.getName f))
    (println (.getName f))
    (let [svd (-> f
                  xml/parse
                  zip/xml-zip)
          output (str "target/" (str/replace (.getName f) #"\.svd(\.patched)?" ".zig"))]
      (spit output (svd->zig svd)))))

(comment

  (def svd
    (-> (java.io.File.
         ;;"vendor/stm32f103.svd.patched"
         "vendor/nrf52833.svd"
         )
        xml/parse
        zip/xml-zip))

  (def ps
    (svd->peripherals svd))

  (def p
    (nth ps 4))

  ;;(peripheral->zig (nth ps 4))

  (->> ps
       (filter #(= "USB" (:name %))))
  )
