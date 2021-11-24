import { useState, useEffect } from "react";

export const useJaLeParameterInterop = (handlerName, initialValue) => {
  const [paramValue, setParamValue] = useState(initialValue);

  useEffect(() => {
    console.log("Param value changed, enforcing update to: " + paramValue);
  }, [paramValue]);

  return [paramValue, setParamValue];
};
