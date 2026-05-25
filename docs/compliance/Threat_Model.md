# Threat Model - Queue Bus (Barbie Doll Queue Bus)

## Overview

### Service Purpose
Queue Bus is a Ruby gem that provides a simple event bus implementation built on top of Redis and background queue systems (Resque/Sidekiq). It enables asynchronous communication between distributed applications through a publish-subscribe pattern, allowing applications to publish events and subscribe to events of interest.

### Scope
This threat model covers the Queue Bus library itself, including:
- Event publishing mechanisms
- Event subscription and dispatch systems
- Redis-based storage and communication
- Worker processes that handle event processing
- Integration points with adapter frameworks (Resque/Sidekiq)

The model does not cover:
- The underlying Redis infrastructure security
- Specific adapter implementations (Resque-bus, Sidekiq-bus)
- Applications using the library (though integration points are discussed)

## Data Flow Diagram

```
┌─────────────────┐
│  Application A  │
│  (Publisher)    │
└────────┬────────┘
         │ publish(event_type, attributes)
         ▼
┌─────────────────┐
│   QueueBus      │
│   Publishing    │
└────────┬────────┘
         │ add metadata (bus_id, hostname, timestamp)
         ▼
┌─────────────────┐
│     Redis       │
│  Incoming Queue │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Driver Worker  │
│  (Fan-out)      │
└────────┬────────┘
         │ match subscriptions
         ▼
┌─────────────────┐
│     Redis       │
│ Subscription DB │
│ + App Queues    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Rider Workers  │
│  (Per App)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Application B  │
│  (Subscriber)   │
└─────────────────┘
```

## Dependencies

### External Libraries
- **redis**: Core dependency for event storage and queue management
- **multi_json**: JSON serialization/deserialization
- **securerandom**: UUID generation for event identifiers

### Background Queue Adapters (via separate gems)
- **resque**: Optional adapter for job processing
- **sidekiq**: Optional adapter for job processing
- **resque-scheduler**: Delayed job scheduling support
- **resque-retry**: Retry logic for failed jobs

### Ruby Standard Libraries
- **Time**: Timestamp generation
- **I18n**: Internationalization support (optional)
- **Forwardable**: Delegation pattern
- **Logger**: Logging functionality

### Infrastructure
- **Redis Server**: Required for all queue and subscription storage
- **Background Worker Processes**: Resque/Sidekiq workers that process events

## Entry Points

### 1. Event Publishing API
- **Location**: `QueueBus.publish(event_type, attributes)`
- **Purpose**: Accept events from applications for distribution
- **Input**: Event type (string), attributes (hash)
- **Authentication**: None (relies on application-level trust)
- **Access Control**: None

### 2. Delayed Event Publishing API
- **Location**: `QueueBus.publish_at(timestamp, event_type, attributes)`
- **Purpose**: Schedule events for future publishing
- **Input**: Timestamp, event type, attributes
- **Authentication**: None
- **Access Control**: None

### 3. Subscription Registration
- **Location**: `QueueBus.dispatch(app_key) { subscribe ... }`
- **Purpose**: Register event subscriptions for applications
- **Input**: Application key, subscription matchers, callbacks
- **Authentication**: None
- **Access Control**: Application key based isolation

### 4. Redis Queue Interface
- **Location**: Redis incoming queue (configurable name)
- **Purpose**: Receive serialized events from Redis
- **Input**: Serialized event data
- **Authentication**: Redis connection credentials
- **Access Control**: Redis ACLs (if configured)

### 5. Rake Tasks
- **Location**: `rake queuebus:subscribe`
- **Purpose**: Administrative subscription management
- **Input**: Application subscription definitions from code
- **Authentication**: System-level access required
- **Access Control**: Operating system user permissions

### 6. Worker Processes
- **Location**: Driver and Rider worker classes
- **Purpose**: Process events from queues
- **Input**: Serialized event data from Redis queues
- **Authentication**: Redis connection credentials
- **Access Control**: Queue name isolation

## Exit Points

### 1. Redis Storage
- **Location**: Redis HSET, SADD operations
- **Data**: Subscription metadata, serialized events
- **Protection**: Redis authentication, network isolation
- **Sensitivity**: High (contains event data and routing information)

### 2. Subscriber Callbacks
- **Location**: User-defined blocks in subscriptions
- **Data**: Complete event attributes including metadata
- **Protection**: Application code trust boundary
- **Sensitivity**: Varies by event content

### 3. Application Logs
- **Location**: `QueueBus.logger` calls
- **Data**: Event types, attributes, metadata, error messages
- **Protection**: Log file permissions, log aggregation security
- **Sensitivity**: Medium to High (may contain sensitive event data)

### 4. Worker Queue Enqueue
- **Location**: Adapter enqueue operations
- **Data**: Serialized events with routing metadata
- **Protection**: Redis security, queue isolation
- **Sensitivity**: High (contains full event payload)

### 5. Heartbeat Events
- **Location**: Scheduled heartbeat publishing
- **Data**: Heartbeat event metadata
- **Protection**: Same as regular events
- **Sensitivity**: Low (typically metadata only)

## Assets

### Critical Assets

1. **Event Data**
   - Description: User/application data transmitted through events
   - Sensitivity: High (may contain PII, business logic data)
   - Storage: Redis queues (transient)
   - Access: Publishers, workers, subscribers

2. **Subscription Configuration**
   - Description: Event routing rules and application keys
   - Sensitivity: Medium (defines application architecture)
   - Storage: Redis hash structures
   - Access: Applications during registration, Driver during routing

3. **Redis Connection Credentials**
   - Description: Authentication details for Redis access
   - Sensitivity: Critical
   - Storage: Application configuration
   - Access: Queue Bus library, worker processes

### Important Assets

4. **Event Metadata**
   - Description: bus_id, timestamps, hostname, locale, timezone
   - Sensitivity: Low to Medium
   - Storage: Attached to all events
   - Access: All components

5. **Application Keys**
   - Description: Identifiers for subscribing applications
   - Sensitivity: Low
   - Storage: Redis sets and keys
   - Access: Public within system

6. **Queue Names**
   - Description: Redis queue identifiers for routing
   - Sensitivity: Low
   - Storage: Subscription configuration
   - Access: Public within system

## Trust Levels

### Level 0: Unauthenticated/Untrusted
- Description: No components operate at this level
- Access: None
- Notes: System assumes all access is from trusted applications

### Level 1: Publishing Applications (Trusted)
- Description: Applications that publish events to the bus
- Access: Can publish events, read own queue results
- Capabilities: 
  - Publish events with arbitrary data
  - Set event metadata (type, attributes)
  - Schedule delayed events
- Trust Boundary: Assumed to be trusted; no validation

### Level 2: Subscribing Applications (Trusted)
- Description: Applications that subscribe to and process events
- Access: Can register subscriptions, receive matched events
- Capabilities:
  - Define subscription matchers
  - Execute arbitrary code in callbacks
  - Access all event data for matched events
- Trust Boundary: Assumed to be trusted; subscription logic executed without sandboxing

### Level 3: Queue Bus Library (Highly Trusted)
- Description: The Queue Bus gem itself
- Access: Full access to Redis, event routing, worker execution
- Capabilities:
  - Route events to queues
  - Store/retrieve subscription data
  - Execute worker processes
  - Generate event metadata
- Trust Boundary: Core trusted component

### Level 4: Infrastructure (Critical Trust)
- Description: Redis, worker processes, system administrators
- Access: Complete system access
- Capabilities:
  - Read/write all Redis data
  - Control worker processes
  - Modify subscription configuration
  - Access system logs
- Trust Boundary: Infrastructure-level trust required

### Level 5: System Administrators (Full Trust)
- Description: Personnel with system-level access
- Access: Complete control over all components
- Capabilities:
  - Deploy code changes
  - Modify configuration
  - Access logs and data
  - Control infrastructure
- Trust Boundary: Organizational trust

## STRIDE Threat List

### Spoofing Threats

#### S1: Event Source Spoofing
- **Description**: A malicious application publishes events claiming to be from another application
- **STRIDE Category**: Spoofing
- **Impact**: High - Subscribers may process fraudulent events
- **Affected Components**: Publishing API, Event Metadata
- **Likelihood**: Medium (requires compromised application)

#### S2: Application Key Spoofing
- **Description**: Attacker registers subscriptions using another application's key
- **STRIDE Category**: Spoofing
- **Impact**: High - Could receive events intended for other applications
- **Affected Components**: Subscription registration
- **Likelihood**: Medium (requires system access)

#### S3: Worker Impersonation
- **Description**: Rogue worker processes connect to Redis and claim to be legitimate workers
- **STRIDE Category**: Spoofing
- **Impact**: High - Could intercept and process events maliciously
- **Affected Components**: Worker processes, Redis queues
- **Likelihood**: Low (requires infrastructure access)

### Tampering Threats

#### T1: Event Modification in Transit
- **Description**: Events modified while stored in Redis before processing
- **STRIDE Category**: Tampering
- **Impact**: High - Corrupted event data processed by subscribers
- **Affected Components**: Redis storage, serialization layer
- **Likelihood**: Low (requires Redis compromise)

#### T2: Subscription Configuration Tampering
- **Description**: Attacker modifies subscription rules in Redis
- **STRIDE Category**: Tampering
- **Impact**: High - Events routed incorrectly or not at all
- **Affected Components**: Redis subscription storage
- **Likelihood**: Low (requires Redis write access)

#### T3: Event Metadata Injection
- **Description**: Publisher injects malicious metadata (e.g., malformed bus_id, timezone)
- **STRIDE Category**: Tampering
- **Impact**: Medium - Could cause processing errors or exploit vulnerabilities
- **Affected Components**: Publishing API, metadata generation
- **Likelihood**: Medium (publishers are trusted but may have vulnerabilities)

#### T4: Serialization Tampering
- **Description**: Maliciously crafted serialized data exploits deserialization vulnerabilities
- **STRIDE Category**: Tampering
- **Impact**: Critical - Could lead to code execution
- **Affected Components**: Util.encode/decode, multi_json library
- **Likelihood**: Low (requires specific vulnerability)

### Repudiation Threats

#### R1: Event Publishing Denial
- **Description**: Publisher denies having published an event
- **STRIDE Category**: Repudiation
- **Impact**: Medium - Difficulty in auditing and debugging
- **Affected Components**: Publishing API, logging
- **Likelihood**: High (no built-in non-repudiation)

#### R2: Subscription Action Denial
- **Description**: Subscriber denies having processed an event
- **STRIDE Category**: Repudiation
- **Impact**: Medium - Difficult to track event processing
- **Affected Components**: Subscriber callbacks, logging
- **Likelihood**: High (limited audit trail)

#### R3: Administrative Action Denial
- **Description**: Administrator denies modifying subscriptions via rake tasks
- **STRIDE Category**: Repudiation
- **Impact**: Low to Medium - Configuration changes not tracked
- **Affected Components**: Rake tasks, subscription management
- **Likelihood**: High (no audit logging)

### Information Disclosure Threats

#### I1: Sensitive Data in Events
- **Description**: PII or sensitive business data exposed through events
- **STRIDE Category**: Information Disclosure
- **Impact**: High - Privacy violations, compliance issues
- **Affected Components**: Event attributes, Redis storage
- **Likelihood**: High (no built-in data protection)

#### I2: Event Data in Logs
- **Description**: Sensitive event attributes logged in plaintext
- **STRIDE Category**: Information Disclosure
- **Impact**: Medium to High - Depends on log access controls
- **Affected Components**: Logger calls throughout codebase
- **Likelihood**: High (verbose logging enabled)

#### I3: Redis Data Exposure
- **Description**: Redis accessible without authentication or over network
- **STRIDE Category**: Information Disclosure
- **Impact**: Critical - All events and subscriptions exposed
- **Affected Components**: Redis connection configuration
- **Likelihood**: Medium (depends on deployment)

#### I4: Subscription Pattern Disclosure
- **Description**: Subscription patterns reveal application architecture
- **STRIDE Category**: Information Disclosure
- **Impact**: Low to Medium - Aids reconnaissance for attacks
- **Affected Components**: Subscription storage in Redis
- **Likelihood**: High (subscriptions stored in clear)

#### I5: Hostname and Context Leakage
- **Description**: Bus metadata exposes internal hostnames and context information
- **STRIDE Category**: Information Disclosure
- **Impact**: Low - Internal architecture details exposed
- **Affected Components**: publish_metadata method
- **Likelihood**: High (always included in events)

### Denial of Service Threats

#### D1: Event Flood Attack
- **Description**: Malicious publisher floods system with events
- **STRIDE Category**: Denial of Service
- **Impact**: High - System overwhelmed, legitimate events delayed
- **Affected Components**: Publishing API, incoming queue
- **Likelihood**: Medium (requires compromised or malicious application)

#### D2: Redis Resource Exhaustion
- **Description**: Attack fills Redis memory with events or subscriptions
- **STRIDE Category**: Denial of Service
- **Impact**: High - Redis fails, entire system down
- **Affected Components**: Redis storage
- **Likelihood**: Medium

#### D3: Subscription Bomb
- **Description**: Register excessive or computationally expensive subscriptions
- **STRIDE Category**: Denial of Service
- **Impact**: High - Driver slows down matching all subscriptions
- **Affected Components**: Driver.subscription_matches
- **Likelihood**: Low to Medium

#### D4: Malformed Event Processing
- **Description**: Crafted events cause worker crashes or infinite loops
- **STRIDE Category**: Denial of Service
- **Impact**: Medium - Workers fail, events not processed
- **Affected Components**: Worker processing, subscriber callbacks
- **Likelihood**: Low (requires specific vulnerability)

#### D5: Queue Starvation
- **Description**: Priority manipulation or queue flooding starves certain queues
- **STRIDE Category**: Denial of Service
- **Impact**: Medium - Some events never processed
- **Affected Components**: Queue management, adapter layer
- **Likelihood**: Low

### Elevation of Privilege Threats

#### E1: Subscriber Code Injection
- **Description**: Attacker injects malicious code through event attributes processed by subscribers
- **STRIDE Category**: Elevation of Privilege
- **Impact**: Critical - Arbitrary code execution in subscriber context
- **Affected Components**: Subscriber callbacks, event processing
- **Likelihood**: Medium (depends on subscriber implementation)

#### E2: Deserialization Exploit
- **Description**: Crafted serialized data exploits deserialization to execute code
- **STRIDE Category**: Elevation of Privilege
- **Impact**: Critical - Code execution in worker context
- **Affected Components**: Util.decode, JSON parsing
- **Likelihood**: Low (requires specific vulnerability in multi_json)

#### E3: Redis Command Injection
- **Description**: Event attributes or keys used in Redis commands without sanitization
- **STRIDE Category**: Elevation of Privilege
- **Impact**: High - Redis data manipulation or command execution
- **Affected Components**: Application class, subscription storage
- **Likelihood**: Low (application keys are normalized)

#### E4: Worker Privilege Escalation
- **Description**: Worker process exploited to gain higher system privileges
- **STRIDE Category**: Elevation of Privilege
- **Impact**: Critical - System compromise
- **Affected Components**: Worker processes
- **Likelihood**: Low (requires system-level vulnerability)

#### E5: Cross-Application Queue Access
- **Description**: Application subscribes to or accesses queues belonging to another application
- **STRIDE Category**: Elevation of Privilege
- **Impact**: High - Unauthorized access to another application's events
- **Affected Components**: Queue naming, subscription isolation
- **Likelihood**: Low (application keys provide isolation)

## Countermeasures

### Implemented Countermeasures

#### C1: Application Key Normalization
- **Addresses**: E3 (Redis Command Injection)
- **Implementation**: Application.normalize method sanitizes application keys
- **Location**: `lib/queue_bus/application.rb:114-116`
- **Effectiveness**: High for preventing key-based injection

#### C2: Event Metadata Generation
- **Addresses**: S1 (Event Source Spoofing) - Partial
- **Implementation**: publish_metadata adds timestamps, UUIDs, and hostname
- **Location**: `lib/queue_bus/publishing.rb:28-43`
- **Effectiveness**: Medium - provides traceability but not authentication

#### C3: Queue Isolation by Application Key
- **Addresses**: E5 (Cross-Application Queue Access)
- **Implementation**: Queue names prefixed with application key
- **Location**: `lib/queue_bus/application.rb:82-90`
- **Effectiveness**: High - enforces logical separation

#### C4: Local Mode Options
- **Addresses**: D1 (Event Flood Attack) - Testing/Development
- **Implementation**: Suppress, inline, and standalone modes for non-production
- **Location**: `lib/queue_bus/local.rb`, configuration
- **Effectiveness**: Medium - limits production exposure during testing

#### C5: Thread-Safe Context Management
- **Addresses**: D4 (Malformed Event Processing) - Partial
- **Implementation**: with_local_mode and in_context provide isolation
- **Location**: Configuration and Publishing modules
- **Effectiveness**: Medium - prevents cross-thread contamination

### Recommended Countermeasures

#### C6: Event Signing and Verification
- **Addresses**: S1 (Event Source Spoofing), T1 (Event Modification)
- **Priority**: High
- **Implementation**: Sign events with HMAC using shared secret per application
- **Recommendation**: Add optional signature verification in Driver before routing

#### C7: Redis Authentication and Encryption
- **Addresses**: I3 (Redis Data Exposure), T1 (Event Modification)
- **Priority**: Critical
- **Implementation**: 
  - Configure Redis with AUTH password
  - Use Redis TLS/SSL for network encryption
  - Implement Redis ACLs (Redis 6+) for command restriction
- **Recommendation**: Document required Redis security configuration

#### C8: Event Attribute Validation
- **Addresses**: T3 (Event Metadata Injection), E1 (Subscriber Code Injection)
- **Priority**: High
- **Implementation**: 
  - Define schemas for event types
  - Validate attributes before publishing and in subscribers
  - Sanitize string inputs
- **Recommendation**: Provide validation middleware/hooks

#### C9: Rate Limiting
- **Addresses**: D1 (Event Flood Attack), D2 (Redis Resource Exhaustion)
- **Priority**: High
- **Implementation**:
  - Limit events per application per time period
  - Queue size limits
  - Subscription count limits per application
- **Recommendation**: Add configurable rate limiting to publishing API

#### C10: Audit Logging
- **Addresses**: R1 (Event Publishing Denial), R2 (Subscription Action Denial), R3 (Administrative Action Denial)
- **Priority**: Medium
- **Implementation**:
  - Log all publish operations with publisher identity
  - Log subscription registration/changes
  - Log worker processing with event IDs
  - Structured logging with correlation IDs
- **Recommendation**: Implement comprehensive audit trail with configurable detail level

#### C11: Sensitive Data Protection
- **Addresses**: I1 (Sensitive Data in Events), I2 (Event Data in Logs)
- **Priority**: High
- **Implementation**:
  - Provide encryption helpers for sensitive attributes
  - Automatic PII detection and redaction in logs
  - Document best practices for sensitive data handling
- **Recommendation**: Add opt-in field-level encryption support

#### C12: Redis Data Expiration
- **Addresses**: D2 (Redis Resource Exhaustion), I3 (Redis Data Exposure)
- **Priority**: Medium
- **Implementation**:
  - Set TTL on event queues
  - Automatic cleanup of old subscriptions
  - Monitoring of Redis memory usage
- **Recommendation**: Implement automatic cleanup policies

#### C13: Input Sanitization for Deserialization
- **Addresses**: T4 (Serialization Tampering), E2 (Deserialization Exploit)
- **Priority**: High
- **Implementation**:
  - Use safe deserialization options
  - Validate structure before decode
  - Limit object types that can be deserialized
- **Recommendation**: Review multi_json configuration for security

#### C14: Subscription Authorization
- **Addresses**: S2 (Application Key Spoofing), E5 (Cross-Application Queue Access)
- **Priority**: Medium
- **Implementation**:
  - Require authentication for subscription registration
  - Validate application identity during subscribe rake task
  - Implement subscription approval workflow for multi-tenant scenarios
- **Recommendation**: Add optional authentication layer for subscription management

#### C15: Worker Process Isolation
- **Addresses**: E4 (Worker Privilege Escalation), E1 (Subscriber Code Injection)
- **Priority**: Medium
- **Implementation**:
  - Run workers with minimal privileges
  - Use containers or VMs for isolation
  - Separate worker processes per application
- **Recommendation**: Document security best practices for worker deployment

#### C16: Monitoring and Alerting
- **Addresses**: All DoS threats, detection of attacks
- **Priority**: High
- **Implementation**:
  - Monitor event rates and queue depths
  - Alert on anomalous subscription patterns
  - Track worker failures and processing times
  - Redis performance monitoring
- **Recommendation**: Provide built-in metrics and health check endpoints

#### C17: Secure Configuration Management
- **Addresses**: I3 (Redis Data Exposure), S3 (Worker Impersonation)
- **Priority**: Critical
- **Implementation**:
  - Store Redis credentials securely (environment variables, secrets management)
  - Validate configuration on startup
  - Document secure configuration patterns
- **Recommendation**: Add configuration validation and security checks

#### C18: Log Sanitization
- **Addresses**: I2 (Event Data in Logs)
- **Priority**: High
- **Implementation**:
  - Automatically redact sensitive fields in logs
  - Configurable log levels with data inclusion/exclusion
  - Separate security audit logs from application logs
- **Recommendation**: Implement log filtering middleware

#### C19: Circuit Breakers and Timeout Limits
- **Addresses**: D4 (Malformed Event Processing), D5 (Queue Starvation)
- **Priority**: Medium
- **Implementation**:
  - Timeout limits for subscriber callbacks
  - Circuit breakers for failing subscriptions
  - Dead letter queues for problematic events
- **Recommendation**: Add resilience patterns to worker processing

#### C20: Regular Security Audits
- **Addresses**: All threats (detection and prevention)
- **Priority**: Medium
- **Implementation**:
  - Periodic security reviews of code
  - Dependency vulnerability scanning
  - Penetration testing of deployed systems
  - Update threat model as system evolves
- **Recommendation**: Establish security review cadence

## Security Testing Recommendations

1. **Fuzzing**: Test publish API with malformed/malicious event data
2. **Load Testing**: Verify DoS countermeasures under high load
3. **Penetration Testing**: Attempt to exploit identified threats
4. **Dependency Scanning**: Regular checks for vulnerable dependencies
5. **Code Review**: Security-focused review of subscription matching and event routing logic

## Compliance Considerations

- **GDPR**: Event data may contain PII requiring encryption, access controls, and audit trails
- **PCI DSS**: Payment-related events require strong encryption and secure storage
- **HIPAA**: Healthcare events need encryption at rest and in transit
- **SOC 2**: Audit logging and access controls required for compliance

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024 | Security Team | Initial threat model creation |

## References

- [OWASP Threat Modeling](https://owasp.org/www-community/Threat_Modeling)
- [STRIDE Methodology](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [Redis Security](https://redis.io/topics/security)
