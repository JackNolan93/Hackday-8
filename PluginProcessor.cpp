#include "PluginProcessor.h"

#include "PluginEditor.h"

//==============================================================================
AudioPluginAudioProcessor::AudioPluginAudioProcessor ()
    : AudioProcessor (BusesProperties ()
#if ! JucePlugin_IsMidiEffect
    #if ! JucePlugin_IsSynth
                          .withInput ("Input", juce::AudioChannelSet::stereo (), true)
    #endif
                          .withOutput ("Output", juce::AudioChannelSet::stereo (), true)
#endif
      )
{
    addParameter (_cutoff = new juce::AudioParameterFloat ("cutoff",                                      // parameter ID
                                                           "Cutoff",                                      // parameter name
                                                           juce::NormalisableRange<float> (0.0f, 1.0f), // parameter range
                                                           0.5f));
    
    addParameter (_q = new juce::AudioParameterFloat ("q",                                      // parameter ID
                                                      "Resonance",                                 // parameter name
                                                      juce::NormalisableRange<float> (0.0f, 1.0f), // parameter range
                                                      0.5f));
}

AudioPluginAudioProcessor::~AudioPluginAudioProcessor ()
{
}

//==============================================================================
const juce::String AudioPluginAudioProcessor::getName () const
{
    return JucePlugin_Name;
}

bool AudioPluginAudioProcessor::acceptsMidi () const
{
#if JucePlugin_WantsMidiInput
    return true;
#else
    return false;
#endif
}

bool AudioPluginAudioProcessor::producesMidi () const
{
#if JucePlugin_ProducesMidiOutput
    return true;
#else
    return false;
#endif
}

bool AudioPluginAudioProcessor::isMidiEffect () const
{
#if JucePlugin_IsMidiEffect
    return true;
#else
    return false;
#endif
}

void AudioPluginAudioProcessor::setCutoff (float cutoff)
{
    *_cutoff = cutoff;
    
    if (_prevCutoff != _cutoff->get ())
    {
        _svFilter.setCutoffFrequency ((_cutoff->get () * 20000.f) + 20.f);
        _prevCutoff =_cutoff->get ();
    }
}

void AudioPluginAudioProcessor::setq (float q)
{
    *_q = q;
    _svFilter.setResonance (_q->get () * 5.f);
}


double AudioPluginAudioProcessor::getTailLengthSeconds () const
{
    return 0.0;
}

int AudioPluginAudioProcessor::getNumPrograms ()
{
    return 1; // NB: some hosts don't cope very well if you tell them there are 0 programs,
              // so this should be at least 1, even if you're not really implementing programs.
}

int AudioPluginAudioProcessor::getCurrentProgram ()
{
    return 0;
}

void AudioPluginAudioProcessor::setCurrentProgram (int index)
{
    juce::ignoreUnused (index);
}

const juce::String AudioPluginAudioProcessor::getProgramName (int index)
{
    juce::ignoreUnused (index);
    return {};
}

void AudioPluginAudioProcessor::changeProgramName (int index, const juce::String & newName)
{
    juce::ignoreUnused (index, newName);
}

//==============================================================================
void AudioPluginAudioProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = juce::uint32 (samplesPerBlock);
    spec.numChannels = juce::uint32 (getTotalNumInputChannels ());
    
    _svFilter.prepare (spec);
    
    _svFilter.setType (juce::dsp::StateVariableTPTFilterType::lowpass);
    _svFilter.setCutoffFrequency (5000.f);
    _svFilter.setResonance (1.f);
    
}

void AudioPluginAudioProcessor::releaseResources ()
{
    // When playback stops, you can use this as an opportunity to free up any
    // spare memory, etc.
}

bool AudioPluginAudioProcessor::isBusesLayoutSupported (const BusesLayout & layouts) const
{
#if JucePlugin_IsMidiEffect
    juce::ignoreUnused (layouts);
    return true;
#else
    // This is the place where you check if the layout is supported.
    // In this template code we only support mono or stereo.
    // Some plugin hosts, such as certain GarageBand versions, will only
    // load plugins that support stereo bus layouts.
    if (layouts.getMainOutputChannelSet () != juce::AudioChannelSet::mono () &&
        layouts.getMainOutputChannelSet () != juce::AudioChannelSet::stereo ())
        return false;

        // This checks if the input layout matches the output layout
    #if ! JucePlugin_IsSynth
    if (layouts.getMainOutputChannelSet () != layouts.getMainInputChannelSet ())
        return false;
    #endif

    return true;
#endif
}

void AudioPluginAudioProcessor::processBlock (juce::AudioBuffer<float> & buffer,
                                              juce::MidiBuffer & midiMessages)
{
    juce::ignoreUnused (midiMessages);

    juce::ScopedNoDenormals noDenormals;
    auto totalNumInputChannels = getTotalNumInputChannels ();
    auto totalNumOutputChannels = getTotalNumOutputChannels ();
    
    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear (i, 0, buffer.getNumSamples ());

    juce::dsp::AudioBlock<float> block (buffer);
    juce::dsp::ProcessContextReplacing <float> context (block);
    
    _svFilter.process (context);
}

//==============================================================================
bool AudioPluginAudioProcessor::hasEditor () const
{
    return true; // (change this to false if you choose to not supply an editor)
}

juce::AudioProcessorEditor * AudioPluginAudioProcessor::createEditor ()
{
    return new AudioPluginAudioProcessorEditor (*this);
}

//==============================================================================
void AudioPluginAudioProcessor::getStateInformation (juce::MemoryBlock & destData)
{
    // You should use this method to store your parameters in the memory block.
    // You could do that either as raw data, or use the XML or ValueTree classes
    // as intermediaries to make it easy to save adnd load complex data.
    juce::ignoreUnused (destData);
}

void AudioPluginAudioProcessor::setStateInformation (const void * data, int sizeInBytes)
{
    // You should use this method to restore your parameters from this memory block,
    // whose contents will have been created by the getStateInformation() call.
    juce::ignoreUnused (data, sizeInBytes);
}

//==============================================================================
// This creates new instances of the plugin..
juce::AudioProcessor * JUCE_CALLTYPE createPluginFilter ()
{
    return new AudioPluginAudioProcessor ();
}
