# greeter-wayvnc Specification

## Purpose

Pre-login VNC access on t14 via wayvnc running inside the greetd/regreet Hyprland greeter session. Remote users authenticate at the login screen over VNC before any user session starts.

## Requirements

### Requirement: VNC Access at Login Screen

The system SHALL start wayvnc inside the greeter Hyprland session so that VNC clients connecting to the configured address and port see the regreet login screen.

#### Scenario: VNC client connects to login screen

- GIVEN `omarchy.greeter.wayvnc.enable` is `true`
- AND greetd has started the regreet Hyprland greeter session
- WHEN a VNC client connects to the configured address and port (default `0.0.0.0:5900`)
- THEN the client sees the regreet login screen
- AND can interact with the login UI (keyboard input, display output)

### Requirement: PAM Authentication

The system SHALL configure wayvnc to authenticate VNC clients against the system PAM stack using Unix passwords.

#### Scenario: Successful PAM authentication

- GIVEN wayvnc is running in the greeter session with `enable_pam = true`
- WHEN a VNC client provides valid Unix credentials for an existing user
- THEN the VNC session is established

#### Scenario: Failed PAM authentication

- GIVEN wayvnc is running in the greeter session with `enable_pam = true`
- WHEN a VNC client provides invalid credentials
- THEN the connection is rejected and the greeter screen remains available

### Requirement: Config Deployment

The system SHALL deploy a wayvnc configuration file readable by the `greeter` user with the correct address, port, and PAM settings.

#### Scenario: Config file exists with correct content

- GIVEN `omarchy.greeter.wayvnc.enable` is `true`
- WHEN the system builds and switches
- THEN a wayvnc config file exists at `/var/lib/greeter/.config/wayvnc/config`
- AND contains the configured address, port, and `enable_pam` values

#### Scenario: Config file is readable by greeter user

- GIVEN the wayvnc config file is deployed
- WHEN the `greeter` user reads the file
- THEN the file is readable without permission errors

### Requirement: Login Transition

The system SHALL allow a clean transition from greeter wayvnc to user-session wayvnc when the user authenticates through regreet.

#### Scenario: Seamless VNC handoff at login

- GIVEN a VNC client is connected to greeter wayvnc on port 5900
- WHEN the user successfully authenticates through regreet
- THEN the greeter Hyprland session exits and greeter wayvnc terminates
- AND the user-session wayvnc starts on port 5900
- AND a VNC client with auto-reconnect resumes on the user desktop

#### Scenario: Brief disconnect during handoff

- GIVEN a VNC client is connected to greeter wayvnc
- WHEN login transition occurs
- THEN the VNC connection drops briefly (~1 second)
- AND auto-reconnecting clients re-establish within a reasonable time

### Requirement: Opt-in Gating

The system SHALL gate greeter-wayvnc behind `omarchy.greeter.wayvnc.enable` and produce no greeter-wayvnc artifacts when disabled.

#### Scenario: Feature disabled (default)

- GIVEN `omarchy.greeter.wayvnc.enable` is `false` (default)
- WHEN the system builds
- THEN no wayvnc exec-once line is injected into the greeter Hyprland config
- AND no greeter wayvnc config file is deployed

#### Scenario: Feature enabled

- GIVEN `omarchy.greeter.wayvnc.enable` is `true`
- WHEN the system builds
- THEN wayvnc exec-once is injected into the greeter Hyprland config before regreet
- AND the wayvnc config file is deployed

### Requirement: Port Configuration

The system SHALL allow configuring the greeter wayvnc port via `omarchy.greeter.wayvnc.port`. The greeter and user-session wayvnc MAY share the same port since only one runs at a time.

#### Scenario: Custom port

- GIVEN `omarchy.greeter.wayvnc.enable` is `true`
- AND `omarchy.greeter.wayvnc.port` is set to `5901`
- WHEN wayvnc starts in the greeter session
- THEN wayvnc listens on port `5901`
- AND the deployed config file reflects port `5901`

#### Scenario: Port shared with user session

- GIVEN greeter wayvnc port is `5900`
- AND user-session wayvnc port is `5900`
- WHEN greeter wayvnc exits and user-session wayvnc starts
- THEN no port conflict occurs
