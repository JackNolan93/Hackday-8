import React from "react";
import ParticlesConfig from "./ParticlesConfig";
import Particles from "react-tsparticles";
import {
  Center,
  Slider,
  SliderThumb,
  SliderTrack,
  SliderFilledTrack,
  Box,
  VStack,
  StackDivider,
  FormControl,
  FormLabel,
  FormHelperText,
  Input,
  ChakraProvider,
} from "@chakra-ui/react";

import { MdGraphicEq } from "react-icons/md";

import { useJaLeParameterInterop } from "./JaLeHooks";

const App = () => {
  const [paramValueQ, setParamValueQ] = useJaLeParameterInterop("set_q", 0);

  const [paramValueCutoff, setParamValueCutoff] = useJaLeParameterInterop(
    "set_cutoff",
    0
  );

  return (
    <ChakraProvider>
      <Particles options={ParticlesConfig} className="background_poly" />

      <Center h="100vh" color="white">
        <VStack spacing={4} align="stretch">
          <FormControl id="q_control">
            <FormLabel>Q</FormLabel>
            <Slider
              aria-label="slider-ex-4"
              defaultValue={30}
              value={paramValueQ}
              min={0}
              max={1}
              step={0.001}
              onChange={(val) => {
                setParamValueQ(val);
              }}
            >
              <SliderTrack bg="red.100">
                <SliderFilledTrack bg="tomato" />
              </SliderTrack>
              <SliderThumb boxSize={6}>
                <Box color="tomato" as={MdGraphicEq} />
              </SliderThumb>
            </Slider>
            <FormHelperText>Control the Q of the filter.</FormHelperText>
          </FormControl>
          <FormControl id="cutoff_control">
            <FormLabel>Cutoff</FormLabel>
            <Slider
              aria-label="slider-ex-4"
              defaultValue={30}
              value={paramValueCutoff}
              min={0}
              max={1}
              step={0.001}
              onChange={(val) => {
                setParamValueCutoff(val);
              }}
            >
              <SliderTrack bg="red.100">
                <SliderFilledTrack bg="tomato" />
              </SliderTrack>
              <SliderThumb boxSize={6}>
                <Box color="tomato" as={MdGraphicEq} />
              </SliderThumb>
            </Slider>
            <FormHelperText>Control the cutoff of the filter.</FormHelperText>
          </FormControl>
        </VStack>
      </Center>
    </ChakraProvider>
  );
};

export default App;
