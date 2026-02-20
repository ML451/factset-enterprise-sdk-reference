# FactSet Power BI Integration

This directory contains documentation and resources for integrating FactSet APIs with Microsoft Power BI, focusing on Portfolio Analytics (PA3) and Style, Performance, and Risk Analysis (SPAR) engines.

## Contents

### Documentation

| Document | Description |
|----------|-------------|
| [PA3-SPAR-DataModel-Design.md](./docs/PA3-SPAR-DataModel-Design.md) | Optimal star schema data model design for PA3 and SPAR data |
| [PowerQuery-BestPractices.md](./docs/PowerQuery-BestPractices.md) | Power Query (M language) patterns and best practices |
| [NativeConnector-Architecture.md](./docs/NativeConnector-Architecture.md) | Architecture for building a native Power BI custom connector |
| [UniversalScreening-Insights.md](./docs/UniversalScreening-Insights.md) | Universal Screening API insights for future integration |

### Directory Structure

```
powerbi-integration/
├── README.md                              # This file
├── docs/                                  # Documentation
│   ├── PA3-SPAR-DataModel-Design.md      # Star schema design
│   ├── PowerQuery-BestPractices.md       # Power Query patterns
│   ├── NativeConnector-Architecture.md   # Connector architecture
│   └── UniversalScreening-Insights.md    # Screening API insights
├── power-query/                           # Power Query templates (future)
└── connector/                             # Native connector source (future)
```

## Quick Start

### 1. Understand the Data Model

Start with [PA3-SPAR-DataModel-Design.md](./docs/PA3-SPAR-DataModel-Design.md) to understand:
- Star schema design principles for financial analytics
- Dimension tables (Date, Account, Security, Benchmark, etc.)
- Fact tables (PA3 Performance, SPAR Analysis)
- Relationships and cardinality

### 2. Implement Power Query Functions

Use [PowerQuery-BestPractices.md](./docs/PowerQuery-BestPractices.md) for:
- Authentication setup (OAuth 2.0 and API Key)
- Async calculation handling (submit/poll/retrieve pattern)
- Stach format conversion
- Error handling and rate limiting
- Incremental refresh patterns

### 3. Build Native Connector (Optional)

Follow [NativeConnector-Architecture.md](./docs/NativeConnector-Architecture.md) to:
- Create a certified Power BI custom connector
- Implement OAuth 2.0 flow
- Build navigation tables
- Add IntelliSense documentation

## API Coverage

### Primary APIs (Fully Documented)

| API | Version | Purpose |
|-----|---------|---------|
| **PA Engine** | v3.16.0 | Portfolio Analytics calculations |
| **SPAR Engine** | v3.14.0 | Style, Performance, and Risk Analysis |

### Future Integration (Insights Available)

| API | Version | Purpose |
|-----|---------|---------|
| **Universal Screening** | v2.0.2 | Security selection and filtering |

## Key Features

### Data Model Features
- Shared dimension tables across PA3 and SPAR
- Surrogate keys for optimal join performance
- Support for security-level and group-level analysis
- Incremental refresh compatible design

### Power Query Features
- Secure credential handling
- Async calculation polling with timeout
- Rate limit handling with exponential backoff
- Stach v2 format conversion

### Connector Features
- OAuth 2.0 and API Key authentication
- Browsable navigation tables
- Full function documentation
- Microsoft certification-ready architecture

## Authentication

Both OAuth 2.0 and API Key authentication are supported:

```
OAuth 2.0:
  Authorization URL: https://auth.factset.com/as/authorization.oauth2
  Token URL: https://auth.factset.com/as/token.oauth2

API Key (Basic Auth):
  Base URL: https://api.factset.com
  Format: Basic <base64(username:password)>
```

## Related FactSet SDKs

The Power BI integration leverages these FactSet SDKs:

| Language | PA Engine Package | SPAR Engine Package |
|----------|-------------------|---------------------|
| Python | `fds.sdk.PAEngine` | `fds.sdk.SPAREngine` |
| .NET | `FactSet.SDK.PAEngine` | `FactSet.SDK.SPAREngine` |
| TypeScript | `@factset/sdk-paengine` | `@factset/sdk-sparengine` |
| Java | `com.factset.sdk:paengine` | `com.factset.sdk:sparengine` |

## Contributing

When adding to this Power BI integration:

1. Follow the established documentation patterns
2. Include Power Query (M) code examples
3. Document any new data model extensions
4. Test with actual FactSet API responses

## References

- [FactSet Developer Portal](https://developer.factset.com/)
- [Power BI Custom Connectors](https://docs.microsoft.com/en-us/power-query/startingtodevelopcustomconnectors)
- [Power Query M Reference](https://docs.microsoft.com/en-us/powerquery-m/)
- [Stach Schema Documentation](https://factset.github.io/stachschema/)
