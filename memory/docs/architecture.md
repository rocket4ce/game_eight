# System Architecture - GameEight

## 1. Overall Architecture

GameEight follows the Phoenix Framework's layered architecture pattern with LiveView for real-time interactivity:

```mermaid
flowchart TD
    subgraph "Client Layer"
        Browser[Web Browser]
        WebSocket[WebSocket Connection]
    end

    subgraph "Web Layer (GameEightWeb)"
        Router[Phoenix Router]
        Controller[Controllers]
        LiveView[LiveView Processes]
        Components[Phoenix Components]
        Layouts[Layout Templates]
    end

    subgraph "Business Logic Layer (GameEight)"
        Contexts[Business Contexts]
        Schemas[Ecto Schemas]
        Changesets[Ecto Changesets]
    end

    subgraph "Data Layer"
        Repo[Ecto Repository]
        Database[(PostgreSQL)]
    end

    subgraph "External Services"
        Email[Swoosh Mailer]
        HTTP[Req HTTP Client]
    end

    Browser <--> Router
    Browser <--> WebSocket
    WebSocket <--> LiveView
    Router --> Controller
    Router --> LiveView
    LiveView --> Components
    Components --> Layouts

    Controller --> Contexts
    LiveView --> Contexts
    Contexts --> Schemas
    Contexts --> Changesets
    Contexts --> Repo
    Repo <--> Database

    Contexts --> Email
    Contexts --> HTTP
```

## 2. Component Architecture

### Web Layer Components

```mermaid
flowchart LR
    subgraph "GameEightWeb"
        Endpoint[Phoenix Endpoint]
        Router[Router]

        subgraph "Controllers"
            PageController[PageController]
        end

        subgraph "LiveViews"
            GameLive[Game LiveView]
            LobbyLive[Lobby LiveView]
        end

        subgraph "Components"
            CoreComponents[Core Components]
            GameComponents[Game Components]
            UIComponents[UI Components]
        end

        subgraph "Layouts"
            RootLayout[Root Layout]
            AppLayout[App Layout]
        end
    end

    Endpoint --> Router
    Router --> PageController
    Router --> GameLive
    Router --> LobbyLive

    GameLive --> GameComponents
    LobbyLive --> UIComponents
    GameComponents --> CoreComponents
    UIComponents --> CoreComponents

    GameLive --> AppLayout
    LobbyLive --> AppLayout
    AppLayout --> RootLayout
```

### Business Logic Layer

```mermaid
flowchart TD
    subgraph "GameEight Contexts"
        subgraph "Games Context"
            GameSchema[Game Schema]
            GameLogic[Game Logic]
            GameRepo[Game Repository Functions]
        end

        subgraph "Players Context"
            PlayerSchema[Player Schema]
            PlayerLogic[Player Logic]
            PlayerRepo[Player Repository Functions]
        end

        subgraph "Sessions Context"
            SessionSchema[Session Schema]
            SessionLogic[Session Logic]
            SessionRepo[Session Repository Functions]
        end
    end

    subgraph "Shared Infrastructure"
        Repo[GameEight.Repo]
        PubSub[Phoenix PubSub]
        Cache[Game State Cache]
    end

    GameLogic --> Repo
    PlayerLogic --> Repo
    SessionLogic --> Repo

    GameLogic --> PubSub
    SessionLogic --> PubSub

    GameLogic --> Cache
```

## 3. Data Flow Architecture

### Real-time Game Flow

```mermaid
sequenceDiagram
    participant Browser
    participant LiveView
    participant GameLogic
    participant PubSub
    participant Database
    participant OtherClients

    Browser->>LiveView: User Action (e.g., move)
    LiveView->>GameLogic: Process Move
    GameLogic->>Database: Update Game State
    GameLogic->>PubSub: Broadcast Update
    PubSub->>LiveView: Receive Update
    PubSub->>OtherClients: Notify Other Players
    LiveView->>Browser: Update UI
    OtherClients->>OtherClients: Update Other UIs
```

### Request Processing Flow

```mermaid
flowchart TD
    Request[HTTP Request] --> Endpoint[Phoenix Endpoint]
    Endpoint --> Plugs[Pipeline Plugs]
    Plugs --> Router[Phoenix Router]

    Router --> Controller[Controller Action]
    Router --> LiveView[LiveView Mount]

    Controller --> Context[Business Context]
    LiveView --> Context

    Context --> Database[(Database)]
    Context --> Response[Response/State]

    Response --> Template[Template/Component]
    Template --> Browser[Browser Response]
```

## 4. State Management

### LiveView State Architecture

```mermaid
flowchart TD
    subgraph "Client Browser"
        DOM[DOM Elements]
        Events[User Events]
    end

    subgraph "Server Process"
        LiveViewProcess[LiveView Process]
        SocketState[Socket State]
        Assigns[Template Assigns]
    end

    subgraph "Persistent Storage"
        GameState[Game State Cache]
        Database[(PostgreSQL)]
    end

    Events --> LiveViewProcess
    LiveViewProcess --> SocketState
    SocketState --> Assigns
    Assigns --> DOM

    LiveViewProcess <--> GameState
    GameState <--> Database
```

### Game State Management

```mermaid
flowchart LR
    subgraph "Game Session"
        LiveViewState[LiveView Process State]
        TempState[Temporary Game State]
    end

    subgraph "Persistent Layer"
        GameRecord[Game Database Record]
        PlayerRecords[Player Records]
        SessionData[Session Data]
    end

    subgraph "Real-time Layer"
        PubSub[Phoenix PubSub]
        Broadcasts[Game Broadcasts]
    end

    LiveViewState <--> TempState
    TempState <--> GameRecord
    TempState <--> PubSub
    PubSub --> Broadcasts

    GameRecord <--> PlayerRecords
    GameRecord <--> SessionData
```

## 5. Security Architecture

### Security Layers

```mermaid
flowchart TD
    subgraph "Client Security"
        CSRF[CSRF Tokens]
        SecureHeaders[Security Headers]
        InputValidation[Client Validation]
    end

    subgraph "Transport Security"
        HTTPS[HTTPS/TLS]
        WebSocketSecure[Secure WebSockets]
    end

    subgraph "Application Security"
        Authentication[Authentication Layer]
        Authorization[Authorization Logic]
        SessionSecurity[Secure Sessions]
    end

    subgraph "Data Security"
        EctoValidation[Ecto Validations]
        DatabaseConstraints[DB Constraints]
        SanitizedOutput[Output Sanitization]
    end

    Client --> CSRF
    CSRF --> HTTPS
    HTTPS --> Authentication
    Authentication --> EctoValidation
```

## 6. Scalability Architecture

### Horizontal Scaling Considerations

```mermaid
flowchart TD
    subgraph "Load Balancer"
        LB[Load Balancer]
    end

    subgraph "Application Cluster"
        Node1[Phoenix Node 1]
        Node2[Phoenix Node 2]
        Node3[Phoenix Node 3]
    end

    subgraph "Shared Infrastructure"
        PubSub[Distributed PubSub]
        Database[(Primary Database)]
        Redis[(Session Store)]
    end

    LB --> Node1
    LB --> Node2
    LB --> Node3

    Node1 <--> PubSub
    Node2 <--> PubSub
    Node3 <--> PubSub

    Node1 --> Database
    Node2 --> Database
    Node3 --> Database

    Node1 <--> Redis
    Node2 <--> Redis
    Node3 <--> Redis
```

## 7. Integration Architecture

### External Service Integration

```mermaid
flowchart LR
    subgraph "GameEight Application"
        BusinessLogic[Business Logic]
        ReqClient[Req HTTP Client]
        EmailService[Swoosh Mailer]
    end

    subgraph "External APIs"
        ThirdPartyAPI[Third Party APIs]
        EmailProvider[Email Service Provider]
        WebhookEndpoints[Webhook Endpoints]
    end

    subgraph "Monitoring"
        Telemetry[Telemetry Events]
        Metrics[Metrics Collection]
        Dashboard[Live Dashboard]
    end

    BusinessLogic --> ReqClient
    BusinessLogic --> EmailService

    ReqClient <--> ThirdPartyAPI
    EmailService --> EmailProvider
    ThirdPartyAPI --> WebhookEndpoints

    BusinessLogic --> Telemetry
    Telemetry --> Metrics
    Metrics --> Dashboard
```

## 8. Development Architecture

### Development Environment

```mermaid
flowchart TD
    subgraph "Development Tools"
        MixTasks[Mix Tasks]
        LiveReload[Phoenix Live Reload]
        Dashboard[Live Dashboard]
    end

    subgraph "Code Quality"
        Compiler[Elixir Compiler]
        Formatter[Code Formatter]
        TestSuite[ExUnit Tests]
    end

    subgraph "Asset Pipeline"
        ESBuild[ESBuild Bundler]
        TailwindCSS[TailwindCSS Compiler]
        AssetWatcher[Asset Watchers]
    end

    MixTasks --> Compiler
    Compiler --> Formatter
    Formatter --> TestSuite

    LiveReload --> AssetWatcher
    AssetWatcher --> ESBuild
    AssetWatcher --> TailwindCSS
```

## 9. Deployment Architecture

### Production Deployment

```mermaid
flowchart TD
    subgraph "CI/CD Pipeline"
        Build[Build Release]
        Test[Run Tests]
        Deploy[Deploy Application]
    end

    subgraph "Production Environment"
        AppServer[Phoenix Application]
        Database[(PostgreSQL)]
        ReverseProxy[Reverse Proxy]
    end

    subgraph "Monitoring"
        Logs[Application Logs]
        Metrics[Application Metrics]
        Alerts[Alert System]
    end

    Build --> Test
    Test --> Deploy
    Deploy --> AppServer

    ReverseProxy --> AppServer
    AppServer --> Database

    AppServer --> Logs
    AppServer --> Metrics
    Metrics --> Alerts
```

## 10. Component Interaction Patterns

### LiveView Communication Patterns

1. **Parent-Child Component Communication**
   - Parent passes data via assigns
   - Child sends events to parent via `send/2`

2. **Sibling Component Communication**
   - Mediated through parent LiveView
   - Uses Phoenix PubSub for loose coupling

3. **Cross-Process Communication**
   - Phoenix PubSub for real-time broadcasts
   - GenServer processes for stateful operations
   - Database for persistent state sharing

## 11. Error Handling Architecture

```mermaid
flowchart TD
    subgraph "Error Sources"
        UserError[User Input Errors]
        SystemError[System Errors]
        NetworkError[Network Errors]
    end

    subgraph "Error Handling"
        Validation[Input Validation]
        ErrorBoundary[Error Boundaries]
        Fallbacks[Graceful Fallbacks]
    end

    subgraph "Error Recovery"
        UserFeedback[User Feedback]
        SystemRecovery[System Recovery]
        Logging[Error Logging]
    end

    UserError --> Validation
    SystemError --> ErrorBoundary
    NetworkError --> Fallbacks

    Validation --> UserFeedback
    ErrorBoundary --> SystemRecovery
    Fallbacks --> Logging
```
