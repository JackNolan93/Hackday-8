import { useState, useEffect } from "react";

const useJaLeParameterInterop = (handlerName, initialValue) => {
  const [paramValue, setParamValue] = useState(initialValue);

  return [paramValue, requestParameterChange];
};
