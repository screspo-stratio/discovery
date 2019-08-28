(ns metabase.driver.crossdata
    "Driver for Stratio Crossdata databases. Uses the official Stratio JDBC driver under the hood."
    (:require
      [clojure.java.jdbc :as jdbc]
      [clojure
       [set :as set]
       [string :as str]]
      [metabase.util :as u]
      [honeysql
       [core :as hsql]
       [format :as hformat]
       [helpers :as h]]
      [clojure.tools.logging :as log]
      [metabase.driver :as driver]
      [metabase.models
       [field :refer [Field]]
       [table :refer [Table]]]
      [metabase.driver.sql.query-processor :as sql.qp]
      [metabase.query-processor
       [store :as qp.store]
       [util :as qputil]]
      [metabase.mbql.util :as mbql.u]
      [metabase.driver.sql-jdbc
       [common :as sql-jdbc.common]
       [connection :as sql-jdbc.conn]
       [execute :as sql-jdbc.execute]
       [sync :as sql-jdbc.sync]]
      [metabase.driver.sql.util.unprepare :as unprepare]
      [toucan.db :as db]
      [metabase.util.honeysql-extensions :as hx])
  (:import [java.sql PreparedStatement Time] java.util.Date))

;; Register Crossdata driver
(driver/register! :crossdata, :parent :sql-jdbc)

(defmethod driver/display-name :crossdata [_]
  "Stratio Crossdata")


;(defmethod driver/can-connect? :crossdata [_ details]
;  (log/debug "crossdata/can-connect? call")
;  )


;; Connection to Crossdata database
(defmethod sql-jdbc.conn/connection-details->spec :crossdata [_ {:keys [host port dbname user ssl-option]
                                                                 :or {host "localhost", port 13422, dbname "", user "crossdata-1"}
                                                                 :as details}]
  (println "sql-jdbc.conn/connection-details->spec. Host:" host "port:" port " details:" details)
  (-> (merge {:classname "com.stratio.jdbc.core.jdbc4.StratioDriver"
              :subprotocol "crossdata"
              :subname (if ssl-option
                         (str "//Server=" host ":" port ";UID=" user ";SSL=true;LogLevel=3;LogPath=/tmp/crossdata-jdbc-logs")
                         (str "//Server=" host ":" port ";UID=" user ";LogLevel=3;LogPath=/tmp/crossdata-jdbc-logs"))}
             (dissoc details :host :port :user :ssl :db :ssl-option))
      (sql-jdbc.common/handle-additional-options details,:seperator-style :semicolon)))


;; Querys against Crossdata database
(def ^:private database-type->base-type
  (sql-jdbc.sync/pattern-based-database-type->base-type
   [[#"BIGINT"   :type/BigInteger]
    [#"BIG INT"  :type/BigInteger]
    [#"INT"      :type/Integer]
    [#"TINYINT"  :type/Integer]
    [#"SMALLINT" :type/Integer]
    [#"CHAR"     :type/Text]
    [#"TEXT"     :type/Text]
    [#"CLOB"     :type/Text]
    [#"BLOB"     :type/*]
    [#"REAL"     :type/Float]
    [#"DOUB"     :type/Float]
    [#"FLOA"     :type/Float]
    [#"NUMERIC"  :type/Float]
    [#"DECIMAL"  :type/Decimal]
    [#"BOOLEAN"  :type/Boolean]
    [#"DATETIME" :type/DateTime]
    [#"TIMESTAMP" :type/DateTime]
    [#"DATE"     :type/Date]
    [#"TIME"     :type/Time]
    [#"BINARY"   :type/*]
    [#"ARRAY"    :type/Array]
    [#"MAP"      :type/Dictionary]
    [#"STRUCT"   :type/*]]))

;; Type conversion
(defmethod sql-jdbc.sync/database-type->base-type :crossdata [_ database-type]
    (database-type->base-type database-type))

(def ^:private source-table-alias
  "Default alias for all source tables. (Not for source queries; those still use the default SQL QP alias of `source`.)"
  "default")

;; use `source-table-alias` for the source Table, e.g. `t1.field` instead of the normal `schema.table.field`
(defmethod sql.qp/->honeysql [:crossdata (class Field)]
  [driver field]
  (binding [sql.qp/*table-alias* (or sql.qp/*table-alias* source-table-alias)]
    ((get-method sql.qp/->honeysql [:sql (class Field)]) driver field)))

(defmethod sql.qp/apply-top-level-clause [:crossdata :source-table]
  [driver _ honeysql-form {source-table-id :source-table}]
  (let [{table-name :name, schema :schema} (qp.store/table source-table-id)]
    (h/from honeysql-form [(sql.qp/->honeysql driver (hx/identifier :table schema table-name))
                           (sql.qp/->honeysql driver (hx/identifier :table-alias source-table-alias))])))

;; refresh values in Metabase cache
(defmethod driver/describe-table :crossdata
  [driver {:keys [details] :as database} {table-name :name, schema :schema, :as table}]
  (log/debug (u/format-color 'cyan "crossdata.clj->describe-table"))
  (println "table-name:" table-name " schema:" schema " table:" table)
  ; Do a "refresh schema.table" to update metadata. This is mandatory.
  (with-open [conn (jdbc/get-connection (sql-jdbc.conn/db->pooled-connection-spec database))]
    (jdbc/query {:connection conn}
                [(format "refresh table %s.%s" schema table-name) ]))
  ((get-method driver/describe-table :sql-jdbc) driver database table)

  )


(defn- run-query
  "Run the query itself."
  [{sql :query, :keys [params remark max-rows]} connection]
  (let [options {:identifiers identity
                 :as-arrays?  true
                 :max-rows    max-rows}]
    (with-open [connection (jdbc/get-connection connection)]
      (with-open [^PreparedStatement statement (jdbc/prepare-statement connection sql options)]
        (let [statement        (into [statement] params)
              [columns & rows] (jdbc/query connection statement options)]
          {:rows    (or rows [])
           :columns (map u/qualified-name columns)})))))

(defn run-query-without-timezone
  "Runs the given query without trying to set a timezone"
  [_ _ connection query]
  (run-query query connection))

(defmethod driver/execute-query :crossdata
  [driver {:keys [database settings], query :native, :as outer-query}]

  (log/debug (u/format-color 'cyan "crossdata.clj->execute-query"))
  (println "query:" query " outer-query:" outer-query)
  (let [query (-> (assoc query
                         :remark (qputil/query->remark outer-query)
                         :query  (if (seq (:params query))
                                   (unprepare/unprepare driver (cons (:query query) (:params query)))
                                   (:query query))
                         :max-rows (mbql.u/query->max-rows-limit outer-query))
                  (dissoc :params))]
    (sql-jdbc.execute/do-with-try-catch
     (fn []
       (let [db-connection (sql-jdbc.conn/db->pooled-connection-spec database)]
         (run-query-without-timezone driver settings db-connection query)))))
  )

(defmethod driver/supports? [:crossdata :basic-aggregations]              [_ _] true)
(defmethod driver/supports? [:crossdata :binning]                         [_ _] true)
(defmethod driver/supports? [:crossdata :expression-aggregations]         [_ _] true)
(defmethod driver/supports? [:crossdata :expressions]                     [_ _] true)
(defmethod driver/supports? [:crossdata :native-parameters]               [_ _] true)
(defmethod driver/supports? [:crossdata :nested-queries]                  [_ _] true)
(defmethod driver/supports? [:crossdata :standard-deviation-aggregations] [_ _] true)

(defmethod driver/supports? [:crossdata :foreign-keys] [_ _] true)

(defmethod sql.qp/quote-style :crossdata [_] :mysql)
