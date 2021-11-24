#include "PluginEditor.h"

#include "PluginProcessor.h"

//==============================================================================
AudioPluginAudioProcessorEditor::AudioPluginAudioProcessorEditor (AudioPluginAudioProcessor & p)
    : AudioProcessorEditor (&p)
    , processorRef (p)
{
    juce::ignoreUnused (processorRef);
    // Make sure that before the constructor has finished, you've set the
    // editor's size to whatever you need it to be.
    setSize (400, 300);
    setResizable (true, true);

    addAndMakeVisible (_browserComponent);
    _browserComponent.setBounds (getLocalBounds ());

    _browserComponent.addScriptHandler ("set_q",
                                        [this] (juce::String body)
                                        {
                                            processorRef.setq (body.getFloatValue ());
                                        });

    _browserComponent.addScriptHandler ("set_cutoff",
                                        [this] (juce::String body)
                                        {
                                            processorRef.setCutoff (body.getFloatValue ());
                                        });

    juce::URL indexUrl (juce::File (
        "/Users/jacknolan/Developer/Hackday-8/hackday-8-ui/build/index.html"));
    _browserComponent.goToURL (indexUrl.toString (false));
}

AudioPluginAudioProcessorEditor::~AudioPluginAudioProcessorEditor ()
{
}

void AudioPluginAudioProcessorEditor::resized ()
{
    _browserComponent.setBounds (getLocalBounds ());
}
