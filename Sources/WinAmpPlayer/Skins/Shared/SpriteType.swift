import Foundation

/// Sprite definitions for WinAmp skin elements
public enum SpriteType: Hashable {
    // Main window sprites
    case mainBackground
    case titleBarActive
    case titleBarInactive
    case closeButton(ButtonState)
    case minimizeButton(ButtonState)
    case shadeButton(ButtonState)
    case menuButton(ButtonState)
    
    // Transport controls
    case previousButton(ButtonState)
    case playButton(ButtonState)
    case pauseButton(ButtonState)
    case stopButton(ButtonState)
    case nextButton(ButtonState)
    case ejectButton(ButtonState)
    
    // Sliders
    case volumeSliderTrack
    case volumeSliderThumb(ButtonState)
    case balanceSliderTrack
    case balanceSliderThumb(ButtonState)
    case positionSliderTrack
    case positionSliderThumb(ButtonState)
    
    // Toggles
    case shuffleButton(Bool, ButtonState)
    case repeatButton(Bool, ButtonState)
    case equalizerButton(Bool, ButtonState)
    case playlistButton(Bool, ButtonState)
    
    // Display elements
    case numberDigit(Int) // 0-9
    case timeColon
    case timeMinus
    case stereoIndicator
    case monoIndicator
    case playingIndicator
    case pausedIndicator
    case stoppedIndicator
    
    // Equalizer sprites
    case eqBackground
    case eqSliderTrack
    case eqSliderThumb(ButtonState)
    case eqPresetButton(ButtonState)
    case eqOnOffButton(Bool, ButtonState)
    case eqAutoButton(Bool, ButtonState)
    
    // Playlist sprites  
    case playlistBackground
    case playlistScrollbarTrack
    case playlistScrollbarThumb
    case playlistAddButton(ButtonState)
    case playlistRemoveButton(ButtonState)
    case playlistSelectButton(ButtonState)
    case playlistMiscButton(ButtonState)
    case playlistListButton(ButtonState)
    
    // Raw sprite sheet references (for parser compatibility)
    case main
    case cButtons
    case titleBar  // Use camelCase as Oracle recommended
    case volume
    case balance
    case posBar
    case pledit
    case plEdit  // alternate case
    case numbers
    case text
    case visColor
    case monoster
    case eqMain
    case eq_ex
    case avs
}

/// Button state for sprite selection
public enum ButtonState: Hashable {
    case normal
    case pressed
    case hover
}
