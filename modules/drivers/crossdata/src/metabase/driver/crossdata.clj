(ns metabase.driver.crossdata
    "Driver for Stratio Crossdata databases. Uses the official Stratio JDBC driver under the hood."
    (:require
      [clojure
       [set :as set]
       [string :as str]]
      [metabase.util :as u]
      [clojure.tools.logging :as log]
      [metabase.driver :as driver]
      [metabase.driver.sql-jdbc
       [common :as sql-jdbc.common]
       [connection :as sql-jdbc.conn]]))

;; Register Crossdata driver
(driver/register! :crossdata, :parent :sql-jdbc)

(defmethod driver/display-name :crossdata [_]
  "Stratio Crossdata")


;(defmethod driver/can-connect? :crossdata [_ details]
;  (log/debug "crossdata/can-connect? call")
;  )

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


