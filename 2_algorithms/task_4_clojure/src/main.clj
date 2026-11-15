(require '[clojure.edn :as edn])

(defn find-path [residual vertices source sink]
  (letfn [(dfs [u seen]
            (let [seen (conj seen u)]
              (if (= u sink)
                [[u] seen]
                (loop [remaining vertices, seen seen]
                  (if-let [v (first remaining)]
                    (if (and (not (contains? seen v))
                             (pos? (get residual [u v] 0)))
                      (let [[path visited] (dfs v seen)]
                        (if path
                          [(into [u] path) visited]
                          (recur (rest remaining) visited)))
                      (recur (rest remaining) seen))
                    [nil seen])))))]
    (first (dfs source #{}))))

(defn max-flow [{:keys [vertices edges source sink]}]
  (let [known (set vertices)]
    (when-not (and (vector? vertices) (every? keyword? vertices)
                   (= (count vertices) (count known))
                   (known source) (known sink) (not= source sink)
                   (vector? edges)
                   (every? (fn [edge]
                             (and (vector? edge) (= 3 (count edge))
                                  (let [[u v cap] edge]
                                    (and (known u) (known v)
                                         (integer? cap) (not (neg? cap))))))
                           edges))
      (throw (ex-info "Invalid network" {}))))
  (let [initial (reduce (fn [residual [u v cap]]
                          (update residual [u v] (fnil +' 0) cap))
                        {} edges)]
    (loop [residual initial, total 0]
      (if-let [path (find-path residual vertices source sink)]
        (let [steps (mapv vec (partition 2 1 path))
              delta (apply min (map residual steps))
              next-residual
              (reduce (fn [r [u v]]
                        (-> r
                            (update [u v] -' delta)
                            (update [v u] (fnil +' 0) delta)))
                      residual steps)]
          (println "Augment:" path "by" delta)
          (recur next-residual (+' total delta)))
        total))))

(when-not (= "1" (System/getenv "QUICK_FLOW_LIBRARY"))
  (try
    (let [file (or (first *command-line-args*) "data/network.edn")
          network (edn/read-string (slurp file))
          result (max-flow network)]
      (println "Maximum flow:" result))
    (catch Exception e
      (binding [*out* *err*] (println "Error:" (.getMessage e)))
      (System/exit 1))))
