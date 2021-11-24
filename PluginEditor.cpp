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

    addAndMakeVisible (_browserComponent);
    _browserComponent.setBounds (getLocalBounds ());

    _browserComponent.addScriptHandler ("set_q",
                                        [this] (juce::String body)
                                        {
                                            processorRef.setq (body.getFloatValue ());
                                            juce::Logger::writeToLog ("q value: " + body);
                                        });

    _browserComponent.addScriptHandler ("set_cutoff",
                                        [this] (juce::String body)
                                        {
                                            processorRef.setCutoff (body.getFloatValue ());
                                            juce::Logger::writeToLog ("cutoff value: " + body);
                                        });

    juce::URL indexUrl (juce::File (
        "/Users/leonpaterson-stephens/Documents/Development/Hackday-8/hackday-8-ui/build/index.html"));
    _browserComponent.goToURL (indexUrl.toString (false));
}

AudioPluginAudioProcessorEditor::~AudioPluginAudioProcessorEditor ()
{
}

//==============================================================================
void AudioPluginAudioProcessorEditor::paint (juce::Graphics & g)
{
    // (Our component is opaque, so we must completely fill the background with a solid colour)
    g.fillAll (getLookAndFeel ().findColour (juce::ResizableWindow::backgroundColourId));

    g.setColour (juce::Colours::white);
    g.setFont (15.0f);
    g.drawFittedText ("Hello World!", getLocalBounds (), juce::Justification::centred, 1);
}

void AudioPluginAudioProcessorEditor::resized ()
{
    // This is generally where you'll want to lay out the positions of any
    // subcomponents in your editor..
}
