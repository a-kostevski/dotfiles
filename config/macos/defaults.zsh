#!/bin/zsh

osascript -e 'tell application "System Preferences" to quit'
echo "Configuring macOS"

sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Disable the sound effects on boot
sudo nvram SystemAudioVolume="%80"

# Hide remaining battery time; show percentage
defaults write com.apple.menuextra.battery ShowPercent -bool true
defaults write com.apple.menuextra.battery ShowTime -bool false

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable the crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"

# Disable Notification Center and remove the menu bar icon
sudo launchctl unload -w \
  /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2>/dev/null

# Enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Reveal IP address, hostname, OS version, etc. when clicking the clock in the
# login window
sudo defaults write /Library/Preferences/com.apple.loginwindow \
  AdminHostInfo HostName

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Disable automatic text replacement
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticTextReplacementEnabled -bool false

# Disable automatic substitutions
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSmartQuotesEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSmartDashesEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Increase sound quality for Bluetooth headphones/headsets
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

# Use scroll gesture with the Ctrl (^) modifier key to zoom
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144

# Follow the keyboard focus while zoomed in
defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

# Set language and text formats
defaults write NSGlobalDomain AppleLanguages -array "en"
defaults write NSGlobalDomain AppleLocale -string "en_GB@currency=EUR"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true

# Stop iTunes from responding to the keyboard media keys
launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2>/dev/null

###############################################################################
# Energy saving                                                               #
###############################################################################

# Enable lid wakeup
sudo pmset -a lidwake 1

# Remove the sleep image file to save disk space
# sudo rm /private/var/vm/sleepimage
# # Create a zero-byte file instead…
# sudo touch /private/var/vm/sleepimage
# # …and make sure it can’t be rewritten
# sudo chflags uchg /private/var/vm/sleepimage

###############################################################################
# Screen                                                                      #
###############################################################################

# Save screenshots to folder
defaults write com.apple.screencapture location -string "${HOME}/Pictures/mac-screenshots"

# Save screenshots in PNG format (Opts: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png"

###############################################################################
# Finder                                                                      #
###############################################################################

# Finder: disable window animations and Get Info animations
defaults write com.apple.finder DisableAllAnimations -bool true

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles YES

# Always open everything in Finder's list view.
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Show all extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show item info near icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist

# Show item info to the right of the icons on the desktop
/usr/libexec/PlistBuddy -c "Set DesktopViewSettings:IconViewSettings:labelOnBottom false" ~/Library/Preferences/com.apple.finder.plist

# Disable the warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Expand the following File Info panes:
# “General”, “Open with”, and “Sharing & Permissions”
defaults write com.apple.finder FXInfoPanesExpanded -dict \
  General -bool true \
  OpenWith -bool true \
  Privileges -bool true

# Show the ~/Library folder.
chflags nohidden ~/Library
# Show the /Volumes folder
sudo chflags nohidden /Volumes

# Show exxternal drives, network drives, removable media, and mounted servers on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Show the status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Show the path bar
defaults write com.apple.finder ShowPathbar -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Automatically open a new Finder window when a volume is mounted
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true

# Default search path to whole system & system files
defaults write com.apple.finder FXDefaultSearchScope -string "SCev"

# Enable closing finder
defaults write com.apple.finder QuitMenuItem -bool true

###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Minimize windows into their application’s icon
defaults write com.apple.dock largesize -int 64
defaults write com.apple.dock tilesize -int 32
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock minimize-to-application -bool true

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

###############################################################################
# TextEdit, and Disk Utility                                                  #
###############################################################################

# Use plain text mode for new TextEdit documents
defaults write com.apple.TextEdit RichText -int 0
# Open and save files as UTF-8 in TextEdit
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
# Set tab width to 4 spaces
defaults write com.apple.TextEdit TabWidth -int 4

# Enable the debug menu in Disk Utility
defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.DiskUtility advanced-image-options -bool true

###############################################################################
# Mac App Store                                                               #
###############################################################################

# Enable the WebKit Developer Tools in the Mac App Store
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

# Enable Debug Menu in the Mac App Store
defaults write com.apple.appstore ShowDebugMenu -bool true

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Automatically download apps purchased on other Macs
defaults write com.apple.SoftwareUpdate ConfigDataInstall -int 1

# Turn on app auto-update
defaults write com.apple.commerce AutoUpdate -bool true

###############################################################################
# Terminal & iTerm 2                                                          #
###############################################################################

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Disable line marks
defaults write com.apple.terminal ShowLineMarks -int 0

# Enable “focus follows mouse” for Terminal.app and all X11 apps
defaults write com.apple.terminal FocusFollowsMouse -bool true
defaults write org.x.X11 wm_ffm -bool true

# Enable “focus follows mouse” for Terminal.app and all X11 apps
# i.e. hover over a window and start typing in it without clicking first
#defaults write com.apple.terminal FocusFollowsMouse -bool true
#defaults write org.x.X11 wm_ffm -bool true

# Enable Secure Keyboard Entry in Terminal.app
# See: https://security.stackexchange.com/a/47786/8918
# defaults write com.apple.terminal SecureKeyboardEntry -bool true

# Disable the annoying line marks
# defaults write com.apple.Terminal ShowLineMarks -int 0

###############################################################################
# TouchID for sudo                                                            #
###############################################################################

/usr/bin/sudo /bin/cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
/usr/bin/sudo /usr/bin/sed -i'' -e '/^#auth /s/^#//g' /etc/pam.d/sudo_local

###############################################################################
# Time Machine                                                                #
###############################################################################
# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

###############################################################################
# Safari                                                                      #
###############################################################################
# Don’t send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true
defaults write NSGlobalDomain NSWindowResizeTime .001

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# Expanded Save and Print dialogs by default.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
###############################################################################
# Harden                                                                      #
###############################################################################
# source ./harden.zsh
###############################################################################
# Kill affected applications                                                  #
###############################################################################

for app in "Activity Monitor" \
  "Address Book" \
  "Calendar" \
  "cfprefsd" \
  "Contacts" \
  "Dock" \
  "Finder" \
  "Google Chrome Canary" \
  "Google Chrome" \
  "Mail" \
  "Messages" \
  "Opera" \
  "Photos" \
  "Safari" \
  "SizeUp" \
  "Spectacle" \
  "SystemUIServer" \
  "Terminal" \
  "Transmission" \
  "iCal"; do
  killall "${app}" &>/dev/null
done

echo "Done. Note that some of these changes require a logout/restart to take effect."
