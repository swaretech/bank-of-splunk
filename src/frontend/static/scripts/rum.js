/*
 * Splunk RUM / DXA custom business events (sparse, low-cardinality attributes only).
 */
var BankRum = (function () {
  var BLOCKED_ATTR_KEYS = /^(user|email|account|password|token|session)/i;

  function isEnabled() {
    return typeof SplunkRum !== 'undefined' && SplunkRum !== null;
  }

  function sanitizeAttributes(attrs) {
    var safe = {};
    if (!attrs) {
      return safe;
    }
    Object.keys(attrs).forEach(function (key) {
      if (!BLOCKED_ATTR_KEYS.test(key)) {
        safe[key] = attrs[key];
      }
    });
    return safe;
  }

  function reportEvent(eventName, attrs) {
    if (!isEnabled()) {
      return;
    }
    var payload = sanitizeAttributes(attrs || {});
    payload['event.name'] = eventName;
    SplunkRum.reportError(new Error(eventName), payload);
  }

  function firstInvalidField(form) {
    var invalid = form.querySelector(':invalid');
    return invalid && invalid.name ? invalid.name : undefined;
  }

  return {
    isEnabled: isEnabled,
    reportEvent: reportEvent,
    reportValidationFailed: function (form) {
      if (!form) {
        return;
      }
      reportEvent('form.validation_failed', {
        'track.id': form.dataset.trackid || form.id || 'unknown-form',
        field: firstInvalidField(form),
      });
    },
    reportSubmitStarted: function (form, submitButton) {
      var trackId = submitButton && submitButton.dataset
        ? submitButton.dataset.trackid
        : undefined;
      if (!trackId && form) {
        trackId = form.dataset.trackid || form.id;
      }
      reportEvent('form.submit_started', {
        'track.id': trackId || 'unknown-submit',
      });
    },
    reportModalOpened: function (modalName) {
      reportEvent('ui.modal_opened', { modal: modalName });
    },
    reportLoginFailed: function () {
      reportEvent('auth.login_failed', {});
    },
  };
})();
