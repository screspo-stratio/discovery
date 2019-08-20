(ns metabase.driver.crossdata
    "Driver for Stratio Crossdata databases. Uses the official Stratio JDBC driver under the hood."
    (:require
      [clojure
       [set :as set]
       [string :as str]]
      [metabase.driver :as driver]
      [metabase.driver.sql-jdbc
       [common :as sql-jdbc.common]]))

;; Register Crossdata driver
(driver/register! :crossdata, :parent :sql-jdbc)

(defmethod driver/display-name :crossdata [_]
  "Stratio Crossdata")


(defmethod driver/can-connect? :crossdata [_ details]
  )



(defmethod sql-jdbc.conn/connection-details->spec :crossdata [_ details]
  (-> details
      (update :port (fn [port]
                      (if (string? port)
                        (Integer/parseInt port)
                        port)))
      (set/rename-keys {:dbname :db})
      crossdata
      (sql-jdbc.common/handle-additional-options details)))
