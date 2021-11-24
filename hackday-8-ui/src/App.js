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

const App = () => {
  return (
    <ChakraProvider>
      <Particles
        options={ParticlesConfig}
        className="background_poly"
        loaded={() => {
          console.log("Loaded mask.");
        }}
      />

      <Center h="100vh" color="white">
        <VStack spacing={4} align="stretch">
          <FormControl id="q_control">
            <FormLabel>Q</FormLabel>
            <Slider aria-label="slider-ex-4" defaultValue={30}>
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
            <Slider aria-label="slider-ex-4" defaultValue={30}>
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
