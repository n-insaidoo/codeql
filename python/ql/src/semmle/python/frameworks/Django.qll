/**
 * Provides classes modeling security-relevant aspects of the `django` PyPI package.
 * See https://www.djangoproject.com/.
 */

private import python
private import semmle.python.dataflow.new.DataFlow
private import semmle.python.dataflow.new.RemoteFlowSources
private import semmle.python.dataflow.new.TaintTracking
private import semmle.python.Concepts
private import semmle.python.frameworks.PEP249
private import semmle.python.regex

/**
 * Provides models for the `django` PyPI package.
 * See https://www.djangoproject.com/.
 */
private module Django {
  // ---------------------------------------------------------------------------
  // django
  // ---------------------------------------------------------------------------
  /** Gets a reference to the `django` module. */
  private DataFlow::Node django(DataFlow::TypeTracker t) {
    t.start() and
    result = DataFlow::importNode("django")
    or
    exists(DataFlow::TypeTracker t2 | result = django(t2).track(t2, t))
  }

  /** Gets a reference to the `django` module. */
  DataFlow::Node django() { result = django(DataFlow::TypeTracker::end()) }

  /**
   * Gets a reference to the attribute `attr_name` of the `django` module.
   * WARNING: Only holds for a few predefined attributes.
   */
  private DataFlow::Node django_attr(DataFlow::TypeTracker t, string attr_name) {
    attr_name in ["db", "urls", "http", "conf"] and
    (
      t.start() and
      result = DataFlow::importNode("django" + "." + attr_name)
      or
      t.startInAttr(attr_name) and
      result = DataFlow::importNode("django")
    )
    or
    // Due to bad performance when using normal setup with `django_attr(t2, attr_name).track(t2, t)`
    // we have inlined that code and forced a join
    exists(DataFlow::TypeTracker t2 |
      exists(DataFlow::StepSummary summary |
        django_attr_first_join(t2, attr_name, result, summary) and
        t = t2.append(summary)
      )
    )
  }

  pragma[nomagic]
  private predicate django_attr_first_join(
    DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res, DataFlow::StepSummary summary
  ) {
    DataFlow::StepSummary::step(django_attr(t2, attr_name), res, summary)
  }

  /**
   * Gets a reference to the attribute `attr_name` of the `django` module.
   * WARNING: Only holds for a few predefined attributes.
   */
  private DataFlow::Node django_attr(string attr_name) {
    result = django_attr(DataFlow::TypeTracker::end(), attr_name)
  }

  /** Provides models for the `django` module. */
  module django {
    // -------------------------------------------------------------------------
    // django.db
    // -------------------------------------------------------------------------
    /** Gets a reference to the `django.db` module. */
    DataFlow::Node db() { result = django_attr("db") }

    class DjangoDb extends PEP249Module {
      DjangoDb() { this = db() }
    }

    /** Provides models for the `django.db` module. */
    module db {
      /** Gets a reference to the `django.db.connection` object. */
      private DataFlow::Node connection(DataFlow::TypeTracker t) {
        t.start() and
        result = DataFlow::importNode("django.db.connection")
        or
        t.startInAttr("connection") and
        result = db()
        or
        exists(DataFlow::TypeTracker t2 | result = connection(t2).track(t2, t))
      }

      /** Gets a reference to the `django.db.connection` object. */
      DataFlow::Node connection() { result = connection(DataFlow::TypeTracker::end()) }

      class DjangoDbConnection extends Connection::InstanceSource {
        DjangoDbConnection() { this = connection() }
      }

      // -------------------------------------------------------------------------
      // django.db.models
      // -------------------------------------------------------------------------
      // NOTE: The modelling of django models is currently fairly incomplete.
      // It does not fully take `Model`s, `Manager`s, `and QuerySet`s into account.
      // It simply identifies some common dangerous cases.
      /** Gets a reference to the `django.db.models` module. */
      private DataFlow::Node models(DataFlow::TypeTracker t) {
        t.start() and
        result = DataFlow::importNode("django.db.models")
        or
        t.startInAttr("models") and
        result = django()
        or
        exists(DataFlow::TypeTracker t2 | result = models(t2).track(t2, t))
      }

      /** Gets a reference to the `django.db.models` module. */
      DataFlow::Node models() { result = models(DataFlow::TypeTracker::end()) }

      /** Provides models for the `django.db.models` module. */
      module models {
        /** Provides models for the `django.db.models.Model` class. */
        module Model {
          /** Gets a reference to the `django.db.models.Model` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = DataFlow::importNode("django.db.models.Model")
            or
            t.startInAttr("Model") and
            result = models()
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.db.models.Model` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }
        }

        /** Gets a reference to the `objects` object of a django model. */
        private DataFlow::Node objects(DataFlow::TypeTracker t) {
          t.startInAttr("objects") and
          result = Model::classRef()
          or
          exists(DataFlow::TypeTracker t2 | result = objects(t2).track(t2, t))
        }

        /** Gets a reference to the `objects` object of a model. */
        DataFlow::Node objects() { result = objects(DataFlow::TypeTracker::end()) }

        /**
         * Gets a reference to the attribute `attr_name` of an `objects` object.
         * WARNING: Only holds for a few predefined attributes.
         */
        private DataFlow::Node objects_attr(DataFlow::TypeTracker t, string attr_name) {
          attr_name in ["annotate", "extra", "raw"] and
          t.startInAttr(attr_name) and
          result = objects()
          or
          // Due to bad performance when using normal setup with `objects_attr(t2, attr_name).track(t2, t)`
          // we have inlined that code and forced a join
          exists(DataFlow::TypeTracker t2 |
            exists(DataFlow::StepSummary summary |
              objects_attr_first_join(t2, attr_name, result, summary) and
              t = t2.append(summary)
            )
          )
        }

        pragma[nomagic]
        private predicate objects_attr_first_join(
          DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res,
          DataFlow::StepSummary summary
        ) {
          DataFlow::StepSummary::step(objects_attr(t2, attr_name), res, summary)
        }

        /**
         * Gets a reference to the attribute `attr_name` of an `objects` object.
         * WARNING: Only holds for a few predefined attributes.
         */
        DataFlow::Node objects_attr(string attr_name) {
          result = objects_attr(DataFlow::TypeTracker::end(), attr_name)
        }

        /** Gets a reference to the `django.db.models.expressions` module. */
        private DataFlow::Node expressions(DataFlow::TypeTracker t) {
          t.start() and
          result = DataFlow::importNode("django.db.models.expressions")
          or
          t.startInAttr("expressions") and
          result = models()
          or
          exists(DataFlow::TypeTracker t2 | result = expressions(t2).track(t2, t))
        }

        /** Gets a reference to the `django.db.models.expressions` module. */
        DataFlow::Node expressions() { result = expressions(DataFlow::TypeTracker::end()) }

        /** Provides models for the `django.db.models.expressions` module. */
        module expressions {
          /** Provides models for the `django.db.models.expressions.RawSQL` class. */
          module RawSQL {
            /** Gets a reference to the `django.db.models.expressions.RawSQL` class. */
            private DataFlow::Node classRef(DataFlow::TypeTracker t) {
              t.start() and
              result = DataFlow::importNode("django.db.models.expressions.RawSQL")
              or
              t.start() and
              result = DataFlow::importNode("django.db.models.RawSQL") // Commonly used alias
              or
              t.startInAttr("RawSQL") and
              result = expressions()
              or
              exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
            }

            /**
             * Gets a reference to the `django.db.models.expressions.RawSQL` class.
             */
            DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

            /** Gets an instance of the `django.db.models.expressions.RawSQL` class. */
            private DataFlow::Node instance(DataFlow::TypeTracker t, ControlFlowNode sql) {
              t.start() and
              exists(CallNode c | result.asCfgNode() = c |
                c.getFunction() = classRef().asCfgNode() and
                c.getArg(0) = sql
              )
              or
              exists(DataFlow::TypeTracker t2 | result = instance(t2, sql).track(t2, t))
            }

            /** Gets an instance of the `django.db.models.expressions.RawSQL` class. */
            DataFlow::Node instance(ControlFlowNode sql) {
              result = instance(DataFlow::TypeTracker::end(), sql)
            }
          }
        }
      }
    }

    /**
     * A call to the `annotate` function on a model using a `RawSQL` argument.
     *
     * TODO: Consider reworking this to use taint tracking.
     *
     * See https://docs.djangoproject.com/en/3.1/ref/models/querysets/#annotate
     */
    private class ObjectsAnnotate extends SqlExecution::Range, DataFlow::CfgNode {
      override CallNode node;
      ControlFlowNode sql;

      ObjectsAnnotate() {
        node.getFunction() = django::db::models::objects_attr("annotate").asCfgNode() and
        django::db::models::expressions::RawSQL::instance(sql).asCfgNode() in [
            node.getArg(_), node.getArgByName(_)
          ]
      }

      override DataFlow::Node getSql() { result.asCfgNode() = sql }
    }

    /**
     * A call to the `raw` function on a model.
     *
     * See
     * - https://docs.djangoproject.com/en/3.1/topics/db/sql/#django.db.models.Manager.raw
     * - https://docs.djangoproject.com/en/3.1/ref/models/querysets/#raw
     */
    private class ObjectsRaw extends SqlExecution::Range, DataFlow::CfgNode {
      override CallNode node;

      ObjectsRaw() { node.getFunction() = django::db::models::objects_attr("raw").asCfgNode() }

      override DataFlow::Node getSql() { result.asCfgNode() = node.getArg(0) }
    }

    /**
     * A call to the `extra` function on a model.
     *
     * See https://docs.djangoproject.com/en/3.1/ref/models/querysets/#extra
     */
    private class ObjectsExtra extends SqlExecution::Range, DataFlow::CfgNode {
      override CallNode node;

      ObjectsExtra() { node.getFunction() = django::db::models::objects_attr("extra").asCfgNode() }

      override DataFlow::Node getSql() {
        result.asCfgNode() =
          [node.getArg([0, 1, 3, 4]), node.getArgByName(["select", "where", "tables", "order_by"])]
      }
    }

    // -------------------------------------------------------------------------
    // django.urls
    // -------------------------------------------------------------------------
    /** Gets a reference to the `django.urls` module. */
    DataFlow::Node urls() { result = django_attr("urls") }

    /** Provides models for the `django.urls` module */
    module urls {
      /**
       * Gets a reference to the attribute `attr_name` of the `urls` module.
       * WARNING: Only holds for a few predefined attributes.
       */
      private DataFlow::Node urls_attr(DataFlow::TypeTracker t, string attr_name) {
        attr_name in ["path", "re_path"] and
        (
          t.start() and
          result = DataFlow::importNode("django.urls" + "." + attr_name)
          or
          t.startInAttr(attr_name) and
          result = DataFlow::importNode("django.urls")
          or
          t.startInAttr(attr_name) and
          result = django::urls()
        )
        or
        // Due to bad performance when using normal setup with `urls_attr(t2, attr_name).track(t2, t)`
        // we have inlined that code and forced a join
        exists(DataFlow::TypeTracker t2 |
          exists(DataFlow::StepSummary summary |
            urls_attr_first_join(t2, attr_name, result, summary) and
            t = t2.append(summary)
          )
        )
      }

      pragma[nomagic]
      private predicate urls_attr_first_join(
        DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res,
        DataFlow::StepSummary summary
      ) {
        DataFlow::StepSummary::step(urls_attr(t2, attr_name), res, summary)
      }

      /**
       * Gets a reference to the attribute `attr_name` of the `urls` module.
       * WARNING: Only holds for a few predefined attributes.
       */
      private DataFlow::Node urls_attr(string attr_name) {
        result = urls_attr(DataFlow::TypeTracker::end(), attr_name)
      }

      /**
       * Gets a reference to the `django.urls.path` function.
       * See https://docs.djangoproject.com/en/3.0/ref/urls/#path
       */
      DataFlow::Node path() { result = urls_attr("path") }

      /**
       * Gets a reference to the `django.urls.re_path` function.
       * See https://docs.djangoproject.com/en/3.0/ref/urls/#re_path
       */
      DataFlow::Node re_path() { result = urls_attr("re_path") }
    }

    // -------------------------------------------------------------------------
    // django.conf
    // -------------------------------------------------------------------------
    /** Gets a reference to the `django.conf` module. */
    DataFlow::Node conf() { result = django_attr("conf") }

    /** Provides models for the `django.conf` module */
    module conf {
      // -------------------------------------------------------------------------
      // django.conf.urls
      // -------------------------------------------------------------------------
      /** Gets a reference to the `django.conf.urls` module. */
      private DataFlow::Node urls(DataFlow::TypeTracker t) {
        t.start() and
        result = DataFlow::importNode("django.conf.urls")
        or
        t.startInAttr("urls") and
        result = conf()
        or
        exists(DataFlow::TypeTracker t2 | result = urls(t2).track(t2, t))
      }

      // NOTE: had to rename due to shadowing rules in QL
      /** Gets a reference to the `django.conf.urls` module. */
      DataFlow::Node conf_urls() { result = urls(DataFlow::TypeTracker::end()) }

      // NOTE: had to rename due to shadowing rules in QL
      /** Provides models for the `django.conf.urls` module */
      module conf_urls {
        /** Gets a reference to the `django.conf.urls.url` function. */
        private DataFlow::Node url(DataFlow::TypeTracker t) {
          t.start() and
          result = DataFlow::importNode("django.conf.urls.url")
          or
          t.startInAttr("url") and
          result = conf_urls()
          or
          exists(DataFlow::TypeTracker t2 | result = url(t2).track(t2, t))
        }

        /**
         * Gets a reference to the `django.conf.urls.url` function.
         *
         * See https://docs.djangoproject.com/en/1.11/ref/urls/#django.conf.urls.url
         */
        DataFlow::Node url() { result = url(DataFlow::TypeTracker::end()) }
      }
    }

    // -------------------------------------------------------------------------
    // django.http
    // -------------------------------------------------------------------------
    /** Gets a reference to the `django.http` module. */
    DataFlow::Node http() { result = django_attr("http") }

    /** Provides models for the `django.http` module */
    module http {
      /**
       * Gets a reference to the attribute `attr_name` of the `django.http` module.
       * WARNING: Only holds for a few predefined attributes.
       */
      private DataFlow::Node http_attr(DataFlow::TypeTracker t, string attr_name) {
        attr_name in [
            // request
            "request", "HttpRequest",
            // response
            "response", "HttpResponse",
            // HttpResponse subclasses
            "HttpResponseRedirect", "HttpResponsePermanentRedirect", "HttpResponseNotModified",
            "HttpResponseBadRequest", "HttpResponseNotFound", "HttpResponseForbidden",
            "HttpResponseNotAllowed", "HttpResponseGone", "HttpResponseServerError", "JsonResponse",
            // HttpResponse-like classes
            "StreamingHttpResponse", "FileResponse"
          ] and
        (
          t.start() and
          result = DataFlow::importNode("django.http" + "." + attr_name)
          or
          t.startInAttr(attr_name) and
          result = django::http()
        )
        or
        // Due to bad performance when using normal setup with `http_attr(t2, attr_name).track(t2, t)`
        // we have inlined that code and forced a join
        exists(DataFlow::TypeTracker t2 |
          exists(DataFlow::StepSummary summary |
            http_attr_first_join(t2, attr_name, result, summary) and
            t = t2.append(summary)
          )
        )
      }

      pragma[nomagic]
      private predicate http_attr_first_join(
        DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res,
        DataFlow::StepSummary summary
      ) {
        DataFlow::StepSummary::step(http_attr(t2, attr_name), res, summary)
      }

      /**
       * Gets a reference to the attribute `attr_name` of the `django.http` module.
       * WARNING: Only holds for a few predefined attributes.
       */
      private DataFlow::Node http_attr(string attr_name) {
        result = http_attr(DataFlow::TypeTracker::end(), attr_name)
      }

      // ---------------------------------------------------------------------------
      // django.http.request
      // ---------------------------------------------------------------------------
      /** Gets a reference to the `django.http.request` module. */
      DataFlow::Node request() { result = http_attr("request") }

      /** Provides models for the `django.http.request` module. */
      module request {
        /**
         * Gets a reference to the attribute `attr_name` of the `django.http.request` module.
         * WARNING: Only holds for a few predefined attributes.
         */
        private DataFlow::Node request_attr(DataFlow::TypeTracker t, string attr_name) {
          attr_name in ["HttpRequest"] and
          (
            t.start() and
            result = DataFlow::importNode("django.http.request" + "." + attr_name)
            or
            t.startInAttr(attr_name) and
            result = django::http::request()
          )
          or
          // Due to bad performance when using normal setup with `request_attr(t2, attr_name).track(t2, t)`
          // we have inlined that code and forced a join
          exists(DataFlow::TypeTracker t2 |
            exists(DataFlow::StepSummary summary |
              request_attr_first_join(t2, attr_name, result, summary) and
              t = t2.append(summary)
            )
          )
        }

        pragma[nomagic]
        private predicate request_attr_first_join(
          DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res,
          DataFlow::StepSummary summary
        ) {
          DataFlow::StepSummary::step(request_attr(t2, attr_name), res, summary)
        }

        /**
         * Gets a reference to the attribute `attr_name` of the `django.http.request` module.
         * WARNING: Only holds for a few predefined attributes.
         */
        private DataFlow::Node request_attr(string attr_name) {
          result = request_attr(DataFlow::TypeTracker::end(), attr_name)
        }

        /**
         * Provides models for the `django.http.request.HttpRequest` class
         *
         * See https://docs.djangoproject.com/en/3.0/ref/request-response/#httprequest-objects
         */
        module HttpRequest {
          /** Gets a reference to the `django.http.request.HttpRequest` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = request_attr("HttpRequest")
            or
            // handle django.http.HttpRequest alias
            t.start() and
            result = http_attr("HttpRequest")
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.request.HttpRequest` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.request.HttpRequest`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use `django::http::request::HttpRequest::instance()` predicate to get
           * references to instances of `django.http.request.HttpRequest`.
           */
          abstract class InstanceSource extends DataFlow::Node { }

          /** Gets a reference to an instance of `django.http.request.HttpRequest`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.request.HttpRequest`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }
      }

      // -------------------------------------------------------------------------
      // django.http.response
      // -------------------------------------------------------------------------
      /** Gets a reference to the `django.http.response` module. */
      DataFlow::Node response() { result = http_attr("response") }

      /** Provides models for the `django.http.response` module */
      module response {
        /**
         * Gets a reference to the attribute `attr_name` of the `django.http.response` module.
         * WARNING: Only holds for a few predefined attributes.
         */
        private DataFlow::Node response_attr(DataFlow::TypeTracker t, string attr_name) {
          attr_name in [
              "HttpResponse",
              // HttpResponse subclasses
              "HttpResponseRedirect", "HttpResponsePermanentRedirect", "HttpResponseNotModified",
              "HttpResponseBadRequest", "HttpResponseNotFound", "HttpResponseForbidden",
              "HttpResponseNotAllowed", "HttpResponseGone", "HttpResponseServerError",
              "JsonResponse",
              // HttpResponse-like classes
              "StreamingHttpResponse", "FileResponse"
            ] and
          (
            t.start() and
            result = DataFlow::importNode("django.http.response" + "." + attr_name)
            or
            t.startInAttr(attr_name) and
            result = response()
          )
          or
          // Due to bad performance when using normal setup with `response_attr(t2, attr_name).track(t2, t)`
          // we have inlined that code and forced a join
          exists(DataFlow::TypeTracker t2 |
            exists(DataFlow::StepSummary summary |
              response_attr_first_join(t2, attr_name, result, summary) and
              t = t2.append(summary)
            )
          )
        }

        pragma[nomagic]
        private predicate response_attr_first_join(
          DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res,
          DataFlow::StepSummary summary
        ) {
          DataFlow::StepSummary::step(response_attr(t2, attr_name), res, summary)
        }

        /**
         * Gets a reference to the attribute `attr_name` of the `django.http.response` module.
         * WARNING: Only holds for a few predefined attributes.
         */
        private DataFlow::Node response_attr(string attr_name) {
          result = response_attr(DataFlow::TypeTracker::end(), attr_name)
        }

        /**
         * Provides models for the `django.http.response.HttpResponse` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponse.
         */
        module HttpResponse {
          /** Gets a reference to the `django.http.response.HttpResponse` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponse")
            or
            // Handle `django.http.HttpResponse` alias
            t.start() and
            result = http_attr("HttpResponse")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponse` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponse`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponse::instance()` to get references to instances of `django.http.response.HttpResponse`.
           */
          abstract class InstanceSource extends HTTP::Server::HttpResponse::Range, DataFlow::Node {
          }

          /** A direct instantiation of `django.http.response.HttpResponse`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() {
              result.asCfgNode() in [node.getArg(1), node.getArgByName("content_type")]
            }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponse`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponse`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        // ---------------------------------------------------------------------------
        // HttpResponse subclasses
        // see https://docs.djangoproject.com/en/3.1/ref/request-response/#httpresponse-subclasses
        // ---------------------------------------------------------------------------
        /**
         * Provides models for the `django.http.response.HttpResponseRedirect` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseRedirect.
         */
        module HttpResponseRedirect {
          /** Gets a reference to the `django.http.response.HttpResponseRedirect` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseRedirect")
            or
            // Handle `django.http.HttpResponseRedirect` alias
            t.start() and
            result = http_attr("HttpResponseRedirect")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseRedirect` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseRedirect`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseRedirect::instance()` to get references to instances of `django.http.response.HttpResponseRedirect`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseRedirect`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              // note that even though browsers like Chrome usually doesn't fetch the
              // content of a redirect, it is possible to observe the body (for example,
              // with cURL).
              result.asCfgNode() in [node.getArg(1), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseRedirect`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseRedirect`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponsePermanentRedirect` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponsePermanentRedirect.
         */
        module HttpResponsePermanentRedirect {
          /** Gets a reference to the `django.http.response.HttpResponsePermanentRedirect` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponsePermanentRedirect")
            or
            // Handle `django.http.HttpResponsePermanentRedirect` alias
            t.start() and
            result = http_attr("HttpResponsePermanentRedirect")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponsePermanentRedirect` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponsePermanentRedirect`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponsePermanentRedirect::instance()` to get references to instances of `django.http.response.HttpResponsePermanentRedirect`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponsePermanentRedirect`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              // note that even though browsers like Chrome usually doesn't fetch the
              // content of a redirect, it is possible to observe the body (for example,
              // with cURL).
              result.asCfgNode() in [node.getArg(1), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponsePermanentRedirect`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponsePermanentRedirect`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponseNotModified` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseNotModified.
         */
        module HttpResponseNotModified {
          /** Gets a reference to the `django.http.response.HttpResponseNotModified` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseNotModified")
            or
            // TODO: remove/expand this part of the template as needed
            // Handle `django.http.HttpResponseNotModified` alias
            t.start() and
            result = http_attr("HttpResponseNotModified")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseNotModified` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseNotModified`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseNotModified::instance()` to get references to instances of `django.http.response.HttpResponseNotModified`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseNotModified`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() { none() }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { none() }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseNotModified`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseNotModified`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponseBadRequest` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseBadRequest.
         */
        module HttpResponseBadRequest {
          /** Gets a reference to the `django.http.response.HttpResponseBadRequest` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseBadRequest")
            or
            // Handle `django.http.HttpResponseBadRequest` alias
            t.start() and
            result = http_attr("HttpResponseBadRequest")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseBadRequest` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseBadRequest`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseBadRequest::instance()` to get references to instances of `django.http.response.HttpResponseBadRequest`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseBadRequest`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseBadRequest`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseBadRequest`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponseNotFound` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseNotFound.
         */
        module HttpResponseNotFound {
          /** Gets a reference to the `django.http.response.HttpResponseNotFound` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseNotFound")
            or
            // Handle `django.http.HttpResponseNotFound` alias
            t.start() and
            result = http_attr("HttpResponseNotFound")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseNotFound` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseNotFound`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseNotFound::instance()` to get references to instances of `django.http.response.HttpResponseNotFound`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseNotFound`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseNotFound`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseNotFound`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponseForbidden` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseForbidden.
         */
        module HttpResponseForbidden {
          /** Gets a reference to the `django.http.response.HttpResponseForbidden` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseForbidden")
            or
            // Handle `django.http.HttpResponseForbidden` alias
            t.start() and
            result = http_attr("HttpResponseForbidden")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseForbidden` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseForbidden`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseForbidden::instance()` to get references to instances of `django.http.response.HttpResponseForbidden`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseForbidden`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseForbidden`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseForbidden`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponseNotAllowed` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseNotAllowed.
         */
        module HttpResponseNotAllowed {
          /** Gets a reference to the `django.http.response.HttpResponseNotAllowed` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseNotAllowed")
            or
            // Handle `django.http.HttpResponseNotAllowed` alias
            t.start() and
            result = http_attr("HttpResponseNotAllowed")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseNotAllowed` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseNotAllowed`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseNotAllowed::instance()` to get references to instances of `django.http.response.HttpResponseNotAllowed`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseNotAllowed`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              // First argument is permitted methods
              result.asCfgNode() in [node.getArg(1), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseNotAllowed`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseNotAllowed`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponseGone` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseGone.
         */
        module HttpResponseGone {
          /** Gets a reference to the `django.http.response.HttpResponseGone` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseGone")
            or
            // Handle `django.http.HttpResponseGone` alias
            t.start() and
            result = http_attr("HttpResponseGone")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseGone` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseGone`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseGone::instance()` to get references to instances of `django.http.response.HttpResponseGone`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseGone`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseGone`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseGone`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.HttpResponseServerError` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponseServerError.
         */
        module HttpResponseServerError {
          /** Gets a reference to the `django.http.response.HttpResponseServerError` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("HttpResponseServerError")
            or
            // Handle `django.http.HttpResponseServerError` alias
            t.start() and
            result = http_attr("HttpResponseServerError")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.HttpResponseServerError` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.HttpResponseServerError`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `HttpResponseServerError::instance()` to get references to instances of `django.http.response.HttpResponseServerError`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.HttpResponseServerError`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseServerError`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.HttpResponseServerError`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.JsonResponse` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#jsonresponse-objects.
         */
        module JsonResponse {
          /** Gets a reference to the `django.http.response.JsonResponse` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("JsonResponse")
            or
            // Handle `django.http.JsonResponse` alias
            t.start() and
            result = http_attr("JsonResponse")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.JsonResponse` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.JsonResponse`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `JsonResponse::instance()` to get references to instances of `django.http.response.JsonResponse`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.JsonResponse`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("data")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "application/json" }
          }

          /** Gets a reference to an instance of `django.http.response.JsonResponse`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.JsonResponse`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        // ---------------------------------------------------------------------------
        // HttpResponse-like classes
        // ---------------------------------------------------------------------------
        /**
         * Provides models for the `django.http.response.StreamingHttpResponse` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#streaminghttpresponse-objects.
         */
        module StreamingHttpResponse {
          /** Gets a reference to the `django.http.response.StreamingHttpResponse` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("StreamingHttpResponse")
            or
            // Handle `django.http.StreamingHttpResponse` alias
            t.start() and
            result = http_attr("StreamingHttpResponse")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.StreamingHttpResponse` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.StreamingHttpResponse`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `StreamingHttpResponse::instance()` to get references to instances of `django.http.response.StreamingHttpResponse`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.StreamingHttpResponse`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("streaming_content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() { result = "text/html" }
          }

          /** Gets a reference to an instance of `django.http.response.StreamingHttpResponse`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.StreamingHttpResponse`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /**
         * Provides models for the `django.http.response.FileResponse` class
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#fileresponse-objects.
         */
        module FileResponse {
          /** Gets a reference to the `django.http.response.FileResponse` class. */
          private DataFlow::Node classRef(DataFlow::TypeTracker t) {
            t.start() and
            result = response_attr("FileResponse")
            or
            // Handle `django.http.FileResponse` alias
            t.start() and
            result = http_attr("FileResponse")
            or
            // subclass
            result.asExpr().(ClassExpr).getABase() = classRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = classRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.http.response.FileResponse` class. */
          DataFlow::Node classRef() { result = classRef(DataFlow::TypeTracker::end()) }

          /**
           * A source of instances of `django.http.response.FileResponse`, extend this class to model new instances.
           *
           * This can include instantiations of the class, return values from function
           * calls, or a special parameter that will be set when functions are called by an external
           * library.
           *
           * Use the predicate `FileResponse::instance()` to get references to instances of `django.http.response.FileResponse`.
           */
          abstract class InstanceSource extends HttpResponse::InstanceSource, DataFlow::Node { }

          /** A direct instantiation of `django.http.response.FileResponse`. */
          private class ClassInstantiation extends InstanceSource, DataFlow::CfgNode {
            override CallNode node;

            ClassInstantiation() { node.getFunction() = classRef().asCfgNode() }

            override DataFlow::Node getBody() {
              result.asCfgNode() in [node.getArg(0), node.getArgByName("streaming_content")]
            }

            // How to support the `headers` argument here?
            override DataFlow::Node getMimetypeOrContentTypeArg() { none() }

            override string getMimetypeDefault() {
              // see https://github.com/django/django/blob/ebb08d19424c314c75908bc6048ff57c2f872269/django/http/response.py#L471-L479
              result = "application/octet-stream"
            }
          }

          /** Gets a reference to an instance of `django.http.response.FileResponse`. */
          private DataFlow::Node instance(DataFlow::TypeTracker t) {
            t.start() and
            result instanceof InstanceSource
            or
            exists(DataFlow::TypeTracker t2 | result = instance(t2).track(t2, t))
          }

          /** Gets a reference to an instance of `django.http.response.FileResponse`. */
          DataFlow::Node instance() { result = instance(DataFlow::TypeTracker::end()) }
        }

        /** Gets a reference to the `django.http.response.HttpResponse.write` function. */
        private DataFlow::Node write(
          django::http::response::HttpResponse::InstanceSource instance, DataFlow::TypeTracker t
        ) {
          t.startInAttr("write") and
          instance = django::http::response::HttpResponse::instance() and
          result = instance
          or
          exists(DataFlow::TypeTracker t2 | result = write(instance, t2).track(t2, t))
        }

        /** Gets a reference to the `django.http.response.HttpResponse.write` function. */
        DataFlow::Node write(django::http::response::HttpResponse::InstanceSource instance) {
          result = write(instance, DataFlow::TypeTracker::end())
        }

        /**
         * A call to the `django.http.response.HttpResponse.write` function.
         *
         * See https://docs.djangoproject.com/en/3.1/ref/request-response/#django.http.HttpResponse.write
         */
        class HttpResponseWriteCall extends HTTP::Server::HttpResponse::Range, DataFlow::CfgNode {
          override CallNode node;
          HTTP::Server::HttpResponse::Range instance;

          HttpResponseWriteCall() { node.getFunction() = write(instance).asCfgNode() }

          override DataFlow::Node getBody() {
            result.asCfgNode() in [node.getArg(0), node.getArgByName("content")]
          }

          override DataFlow::Node getMimetypeOrContentTypeArg() {
            result = instance.getMimetypeOrContentTypeArg()
          }

          override string getMimetypeDefault() { result = instance.getMimetypeDefault() }
        }
      }
    }

    // -------------------------------------------------------------------------
    // django.views
    // -------------------------------------------------------------------------
    /** Gets a reference to the `django.views` module. */
    DataFlow::Node views() { result = django_attr("views") }

    /** Provides models for the `django.views` module */
    module views {
      /**
       * Gets a reference to the attribute `attr_name` of the `django.views` module.
       * WARNING: Only holds for a few predefined attributes.
       */
      private DataFlow::Node views_attr(DataFlow::TypeTracker t, string attr_name) {
        // for 1.11.x, see: https://github.com/django/django/blob/stable/1.11.x/django/views/__init__.py
        attr_name in ["generic", "View"] and
        (
          t.start() and
          result = DataFlow::importNode("django.views" + "." + attr_name)
          or
          t.startInAttr(attr_name) and
          result = views()
        )
        or
        // Due to bad performance when using normal setup with `views_attr(t2, attr_name).track(t2, t)`
        // we have inlined that code and forced a join
        exists(DataFlow::TypeTracker t2 |
          exists(DataFlow::StepSummary summary |
            views_attr_first_join(t2, attr_name, result, summary) and
            t = t2.append(summary)
          )
        )
      }

      pragma[nomagic]
      private predicate views_attr_first_join(
        DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res,
        DataFlow::StepSummary summary
      ) {
        DataFlow::StepSummary::step(views_attr(t2, attr_name), res, summary)
      }

      /**
       * Gets a reference to the attribute `attr_name` of the `django.views` module.
       * WARNING: Only holds for a few predefined attributes.
       */
      private DataFlow::Node views_attr(string attr_name) {
        result = views_attr(DataFlow::TypeTracker::end(), attr_name)
      }

      // -------------------------------------------------------------------------
      // django.views.generic
      // -------------------------------------------------------------------------
      /** Gets a reference to the `django.views.generic` module. */
      DataFlow::Node generic() { result = views_attr("generic") }

      /** Provides models for the `django.views.generic` module */
      module generic {
        /**
         * Gets a reference to the attribute `attr_name` of the `django.views.generic` module.
         * WARNING: Only holds for a few predefined attributes.
         */
        private DataFlow::Node generic_attr(DataFlow::TypeTracker t, string attr_name) {
          // for 3.1.x see: https://github.com/django/django/blob/stable/3.1.x/django/views/generic/__init__.py
          // same for 1.11.x see: https://github.com/django/django/blob/stable/1.11.x/django/views/generic/__init__.py
          attr_name in [
              "View", "TemplateView", "RedirectView", "ArchiveIndexView", "YearArchiveView",
              "MonthArchiveView", "WeekArchiveView", "DayArchiveView", "TodayArchiveView",
              "DateDetailView", "DetailView", "FormView", "CreateView", "UpdateView", "DeleteView",
              "ListView", "GenericViewError"
            ] and
          (
            t.start() and
            result = DataFlow::importNode("django.views.generic" + "." + attr_name)
            or
            t.startInAttr(attr_name) and
            result = generic()
          )
          or
          // Due to bad performance when using normal setup with `generic_attr(t2, attr_name).track(t2, t)`
          // we have inlined that code and forced a join
          exists(DataFlow::TypeTracker t2 |
            exists(DataFlow::StepSummary summary |
              generic_attr_first_join(t2, attr_name, result, summary) and
              t = t2.append(summary)
            )
          )
        }

        pragma[nomagic]
        private predicate generic_attr_first_join(
          DataFlow::TypeTracker t2, string attr_name, DataFlow::Node res,
          DataFlow::StepSummary summary
        ) {
          DataFlow::StepSummary::step(generic_attr(t2, attr_name), res, summary)
        }

        /**
         * Gets a reference to the attribute `attr_name` of the `django.views.generic` module.
         * WARNING: Only holds for a few predefined attributes.
         */
        private DataFlow::Node generic_attr(string attr_name) {
          result = generic_attr(DataFlow::TypeTracker::end(), attr_name)
        }

        /**
         * Provides models for the `django.views.generic.View` class and subclasses.
         *
         * See
         *  - https://docs.djangoproject.com/en/3.1/topics/class-based-views/
         *  - https://docs.djangoproject.com/en/3.1/ref/class-based-views/
         */
        module View {
          /** Gets a reference to the `django.views.generic.View` class or any subclass. */
          private DataFlow::Node subclassRef(DataFlow::TypeTracker t) {
            t.start() and
            result =
              generic_attr([
                  "View",
                  // Known Views
                  "TemplateView", "RedirectView", "ArchiveIndexView", "YearArchiveView",
                  "MonthArchiveView", "WeekArchiveView", "DayArchiveView", "TodayArchiveView",
                  "DateDetailView", "DetailView", "FormView", "CreateView", "UpdateView",
                  "DeleteView", "ListView"
                ])
            or
            // `django.views.View` alias
            t.start() and
            result = views_attr("View")
            or
            // subclasses in project code
            result.asExpr().(ClassExpr).getABase() = subclassRef(t.continue()).asExpr()
            or
            exists(DataFlow::TypeTracker t2 | result = subclassRef(t2).track(t2, t))
          }

          /** Gets a reference to the `django.views.generic.View` class or any subclass. */
          DataFlow::Node subclassRef() { result = subclassRef(DataFlow::TypeTracker::end()) }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // routing modeling
  // ---------------------------------------------------------------------------
  /**
   * Gets a reference to the Function `func`.
   *
   * The idea is that this function should be used as a route handler when setting up a
   * route, but currently it just tracks all functions, since we can't do type-tracking
   * backwards yet (TODO).
   */
  private DataFlow::Node djangoRouteHandlerFunctionTracker(DataFlow::TypeTracker t, Function func) {
    t.start() and
    result = DataFlow::exprNode(func.getDefinition())
    or
    exists(DataFlow::TypeTracker t2 |
      result = djangoRouteHandlerFunctionTracker(t2, func).track(t2, t)
    )
  }

  /**
   * Gets a reference to the Function `func`.
   *
   * The idea is that this function should be used as a route handler when setting up a
   * route, but currently it just tracks all functions, since we can't do type-tracking
   * backwards yet (TODO).
   */
  private DataFlow::Node djangoRouteHandlerFunctionTracker(Function func) {
    result = djangoRouteHandlerFunctionTracker(DataFlow::TypeTracker::end(), func)
  }

  /** A django View class defined in project code. */
  class DjangoViewClassDef extends Class {
    DjangoViewClassDef() { this.getABase() = django::views::generic::View::subclassRef().asExpr() }

    /** Gets a function that could handle incoming requests, if any. */
    DjangoRouteHandler getARequestHandler() {
      // TODO: This doesn't handle attribute assignment. Should be OK, but analysis is not as complete as with
      // points-to and `.lookup`, which would handle `post = my_post_handler` inside class def
      result = this.getAMethod() and
      result.getName() = HTTP::httpVerbLower()
    }

    /** Gets a reference to this class. */
    private DataFlow::Node getARef(DataFlow::TypeTracker t) {
      t.start() and
      result.asExpr().(ClassExpr) = this.getParent()
      or
      exists(DataFlow::TypeTracker t2 | result = this.getARef(t2).track(t2, t))
    }

    /** Gets a reference to this class. */
    DataFlow::Node getARef() { result = this.getARef(DataFlow::TypeTracker::end()) }

    /** Gets a reference to the `as_view` classmethod of this class. */
    private DataFlow::Node asViewRef(DataFlow::TypeTracker t) {
      t.startInAttr("as_view") and
      result = this.getARef()
      or
      exists(DataFlow::TypeTracker t2 | result = this.asViewRef(t2).track(t2, t))
    }

    /** Gets a reference to the `as_view` classmethod of this class. */
    DataFlow::Node asViewRef() { result = this.asViewRef(DataFlow::TypeTracker::end()) }

    /** Gets a reference to the result of calling the `as_view` classmethod of this class. */
    private DataFlow::Node asViewResult(DataFlow::TypeTracker t) {
      t.start() and
      result.asCfgNode().(CallNode).getFunction() = this.asViewRef().asCfgNode()
      or
      exists(DataFlow::TypeTracker t2 | result = asViewResult(t2).track(t2, t))
    }

    /** Gets a reference to the result of calling the `as_view` classmethod of this class. */
    DataFlow::Node asViewResult() { result = asViewResult(DataFlow::TypeTracker::end()) }
  }

  /**
   * A function that is a django route handler, meaning it handles incoming requests
   * with the django framework.
   */
  private class DjangoRouteHandler extends Function {
    DjangoRouteHandler() {
      exists(djangoRouteHandlerFunctionTracker(this))
      or
      any(DjangoViewClassDef vc).getARequestHandler() = this
    }

    /** Gets the index of the request parameter. */
    int getRequestParamIndex() {
      not this.isMethod() and
      result = 0
      or
      this.isMethod() and
      result = 1
    }

    /** Gets the request parameter. */
    Parameter getRequestParam() { result = this.getArg(this.getRequestParamIndex()) }
  }

  /** A data-flow node that sets up a route on a server, using the django framework. */
  abstract private class DjangoRouteSetup extends HTTP::Server::RouteSetup::Range, DataFlow::CfgNode {
    /** Gets the data-flow node that is used as the argument for the view handler. */
    abstract DataFlow::Node getViewArg();

    final override DjangoRouteHandler getARequestHandler() {
      djangoRouteHandlerFunctionTracker(result) = getViewArg()
      or
      exists(DjangoViewClassDef vc |
        getViewArg() = vc.asViewResult() and
        result = vc.getARequestHandler()
      )
    }
  }

  /** A request handler defined in a django view class, that has no known route. */
  private class DjangoViewClassHandlerWithoutKnownRoute extends HTTP::Server::RequestHandler::Range,
    DjangoRouteHandler {
    DjangoViewClassHandlerWithoutKnownRoute() {
      exists(DjangoViewClassDef vc | vc.getARequestHandler() = this) and
      not exists(DjangoRouteSetup setup | setup.getARequestHandler() = this)
    }

    override Parameter getARoutedParameter() {
      // Since we don't know the URL pattern, we simply mark all parameters as a routed
      // parameter. This should give us more RemoteFlowSources but could also lead to
      // more FPs. If this turns out to be the wrong tradeoff, we can always change our mind.
      result in [this.getArg(_), this.getArgByName(_)] and
      not result = any(int i | i <= this.getRequestParamIndex() | this.getArg(i))
    }
  }

  /**
   * Gets the regex that is used by django to find routed parameters when using `django.urls.path`.
   *
   * Taken from https://github.com/django/django/blob/7d1bf29977bb368d7c28e7c6eb146db3b3009ae7/django/urls/resolvers.py#L199
   */
  private string pathRoutedParameterRegex() {
    result = "<(?:(?<converter>[^>:]+):)?(?<parameter>\\w+)>"
  }

  /**
   * A call to `django.urls.path`.
   *
   * See https://docs.djangoproject.com/en/3.0/ref/urls/#path
   */
  private class DjangoUrlsPathCall extends DjangoRouteSetup {
    override CallNode node;

    DjangoUrlsPathCall() { node.getFunction() = django::urls::path().asCfgNode() }

    override DataFlow::Node getUrlPatternArg() {
      result.asCfgNode() = [node.getArg(0), node.getArgByName("route")]
    }

    override DataFlow::Node getViewArg() {
      result.asCfgNode() in [node.getArg(1), node.getArgByName("view")]
    }

    override Parameter getARoutedParameter() {
      // If we don't know the URL pattern, we simply mark all parameters as a routed
      // parameter. This should give us more RemoteFlowSources but could also lead to
      // more FPs. If this turns out to be the wrong tradeoff, we can always change our mind.
      exists(DjangoRouteHandler routeHandler | routeHandler = this.getARequestHandler() |
        not exists(this.getUrlPattern()) and
        result in [routeHandler.getArg(_), routeHandler.getArgByName(_)] and
        not result = any(int i | i <= routeHandler.getRequestParamIndex() | routeHandler.getArg(i))
      )
      or
      exists(string name |
        result = this.getARequestHandler().getArgByName(name) and
        exists(string match |
          match = this.getUrlPattern().regexpFind(pathRoutedParameterRegex(), _, _) and
          name = match.regexpCapture(pathRoutedParameterRegex(), 2)
        )
      )
    }
  }

  /** A Django route setup that uses a Regex to specify route (and routed parameters). */
  abstract private class DjangoRegexRouteSetup extends DjangoRouteSetup {
    override Parameter getARoutedParameter() {
      // If we don't know the URL pattern, we simply mark all parameters as a routed
      // parameter. This should give us more RemoteFlowSources but could also lead to
      // more FPs. If this turns out to be the wrong tradeoff, we can always change our mind.
      exists(DjangoRouteHandler routeHandler | routeHandler = this.getARequestHandler() |
        not exists(this.getUrlPattern()) and
        result in [routeHandler.getArg(_), routeHandler.getArgByName(_)] and
        not result = any(int i | i <= routeHandler.getRequestParamIndex() | routeHandler.getArg(i))
      )
      or
      exists(DjangoRouteHandler routeHandler, DjangoRouteRegex regex |
        routeHandler = this.getARequestHandler() and
        regex.getRouteSetup() = this
      |
        // either using named capture groups (passed as keyword arguments) or using
        // unnamed capture groups (passed as positional arguments)
        not exists(regex.getGroupName(_, _)) and
        // first group will have group number 1
        result =
          routeHandler.getArg(routeHandler.getRequestParamIndex() + regex.getGroupNumber(_, _))
        or
        result = routeHandler.getArgByName(regex.getGroupName(_, _))
      )
    }
  }

  /**
   * A regex that is used to set up a route.
   *
   * Needs this subclass to be considered a RegexString.
   */
  private class DjangoRouteRegex extends RegexString {
    DjangoRegexRouteSetup rePathCall;

    DjangoRouteRegex() {
      this instanceof StrConst and
      DataFlow::exprNode(this).(DataFlow::LocalSourceNode).flowsTo(rePathCall.getUrlPatternArg())
    }

    DjangoRegexRouteSetup getRouteSetup() { result = rePathCall }
  }

  /**
   * A call to `django.urls.re_path`.
   *
   * See https://docs.djangoproject.com/en/3.0/ref/urls/#re_path
   */
  private class DjangoUrlsRePathCall extends DjangoRegexRouteSetup {
    override CallNode node;

    DjangoUrlsRePathCall() {
      node.getFunction() = django::urls::re_path().asCfgNode() and
      // `django.conf.urls.url` (which we support directly with
      // `DjangoConfUrlsUrlCall`), is implemented in Django 2+ as backward compatibility
      // using `django.urls.re_path`. See
      // https://github.com/django/django/blob/stable/3.2.x/django/conf/urls/__init__.py#L22
      // Since we're still installing dependencies and analyzing their source code,
      // without explicitly filtering out this call, we would be double-counting such
      // route-setups :( One practical negative side effect of double-counting it, is
      // that since we can't figure out the URL in the library code calling `django.urls.re_path`
      // (because we only consider local flow), we will for all those cases mark ANY parameter
      // as being a routed-parameter, which can lead to FPs.
      not exists(Module mod |
        mod.getName() = "django.conf.urls.__init__" and
        node.getEnclosingModule() = mod
      )
    }

    override DataFlow::Node getUrlPatternArg() {
      result.asCfgNode() = [node.getArg(0), node.getArgByName("route")]
    }

    override DataFlow::Node getViewArg() {
      result.asCfgNode() in [node.getArg(1), node.getArgByName("view")]
    }
  }

  /**
   * A call to `django.conf.urls.url`.
   *
   * See https://docs.djangoproject.com/en/1.11/ref/urls/#django.conf.urls.url
   */
  private class DjangoConfUrlsUrlCall extends DjangoRegexRouteSetup {
    override CallNode node;

    DjangoConfUrlsUrlCall() { node.getFunction() = django::conf::conf_urls::url().asCfgNode() }

    override DataFlow::Node getUrlPatternArg() {
      result.asCfgNode() = [node.getArg(0), node.getArgByName("regex")]
    }

    override DataFlow::Node getViewArg() {
      result.asCfgNode() in [node.getArg(1), node.getArgByName("view")]
    }
  }

  // ---------------------------------------------------------------------------
  // HttpRequest taint modeling
  // ---------------------------------------------------------------------------
  /** A parameter that will receive the django `HttpRequest` instance when a request handler is invoked. */
  private class DjangoRequestHandlerRequestParam extends django::http::request::HttpRequest::InstanceSource,
    RemoteFlowSource::Range, DataFlow::ParameterNode {
    DjangoRequestHandlerRequestParam() {
      this.getParameter() = any(DjangoRouteSetup setup).getARequestHandler().getRequestParam()
      or
      this.getParameter() = any(DjangoViewClassHandlerWithoutKnownRoute setup).getRequestParam()
    }

    override string getSourceType() { result = "django.http.request.HttpRequest" }
  }

  private class DjangoHttpRequstAdditionalTaintStep extends TaintTracking::AdditionalTaintStep {
    override predicate step(DataFlow::Node nodeFrom, DataFlow::Node nodeTo) {
      nodeFrom = django::http::request::HttpRequest::instance() and
      exists(DataFlow::AttrRead read | nodeTo = read and read.getObject() = nodeFrom |
        read.getAttributeName() in [
            // str / bytes
            "body", "path", "path_info", "method", "encoding", "content_type",
            // django.http.QueryDict
            // TODO: Model QueryDict
            "GET", "POST",
            // dict[str, str]
            "content_params", "COOKIES",
            // dict[str, Any]
            "META",
            // HttpHeaders (case insensitive dict-like)
            "headers",
            // MultiValueDict[str, UploadedFile]
            // TODO: Model MultiValueDict
            // TODO: Model UploadedFile
            "FILES",
            // django.urls.ResolverMatch
            // TODO: Model ResolverMatch
            "resolver_match"
          ]
        // TODO: Handle calls to methods
        // TODO: Handle that a HttpRequest is iterable
      )
    }
  }
}
