import { useState, useEffect } from "react";

export const useJaLeParameterInterop = (handlerName, initialValue) => {
  const [paramValue, setParamValue] = useState(initialValue);

  useEffect(() => {
    console.log("Param value changed, enforcing update to: " + paramValue);
    if (window.webkit && window.webkit.messageHandlers)
      window.webkit.messageHandlers[handlerName].postMessage(`${paramValue}`);
  }, [paramValue]);

  return [paramValue, setParamValue];
};
