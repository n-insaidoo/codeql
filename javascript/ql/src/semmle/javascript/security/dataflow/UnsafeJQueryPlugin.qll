/**
 * Provides a taint-tracking configuration for reasoning about DOM-based
 * cross-site scripting vulnerabilities in unsafe jQuery plugins.
 */

import javascript
import semmle.javascript.security.dataflow.Xss

module UnsafeJQueryPlugin {
  import UnsafeJQueryPluginCustomizations::UnsafeJQueryPlugin

  /**
   * A taint-tracking configuration for reasoning about XSS in unsafe jQuery plugins.
   */
  class Configuration extends TaintTracking::Configuration {
    Configuration() { this = "UnsafeJQueryPlugin" }

    override predicate isSource(DataFlow::Node source) { source instanceof Source }

    override predicate isSink(DataFlow::Node sink) { sink instanceof Sink }

    override predicate isSanitizer(DataFlow::Node node) {
      super.isSanitizer(node)
      or
      node instanceof DomBasedXss::Sanitizer
      or
      node instanceof Sanitizer
    }

    override predicate isAdditionalTaintStep(DataFlow::Node src, DataFlow::Node sink) {
      // jQuery plugins tend to be implemented as classes that store data in fields initialized by the constructor.
      DataFlow::localFieldStep(src, sink)
    }

    override predicate isSanitizerGuard(TaintTracking::SanitizerGuardNode node) {
      super.isSanitizerGuard(node) or
      node instanceof IsElementSanitizer or
      node instanceof IsJQueryObjectSanitizer
    }
  }
}
