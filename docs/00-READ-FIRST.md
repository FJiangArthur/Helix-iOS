# Helix Documentation Hub

Welcome to the Helix documentation! This is your starting point for understanding, developing, and deploying the Helix AI-powered conversation intelligence app for smart glasses.

## Quick Navigation

### New to Helix?
1. Start with the [Project README](../README.md) for project overview
2. Follow the [Quick Start Guide](dev/QUICK_START.md) to get running in 10 minutes
3. Review [Architecture](architecture/Architecture.md) to understand the system

### Common Tasks
- **Setting up development** → [Quick Start Guide](dev/QUICK_START.md)
- **Understanding the codebase** → [Developer Guide](dev/DEVELOPER_GUIDE.md)
- **Deploying to iOS** → [Build & Deploy Workflow](ops/BUILD_DEPLOY_WORKFLOW.md)
- **Using AI services** → [AI Services API](api/AI_SERVICES_API.md)
- **Testing features** → [Testing Strategy](evaluation/TESTING_STRATEGY.md)

---

## Documentation Structure

### 📱 Product Documentation
> **What** we're building and **why**

Essential documents for understanding product vision, requirements, and planning.

- **[Requirements](product/Requirements.md)** - Core software requirements and acceptance criteria
- **[Enhanced Requirements](product/Enhanced-Requirements.md)** - Extended feature specifications
- **[Product Plan](product/PLAN.md)** - Project roadmap and epic planning
- **[Implementation Summary](product/IMPLEMENTATION_SUMMARY.md)** - Overview of implemented features
- **[Implementation Review](product/IMPLEMENTATION_REVIEW.md)** - Code review and quality assessment
- **[Integration Status](product/FINAL_INTEGRATION_STATUS.md)** - Current integration state
- **[AI Features Plan](product/AI_FEATURES_IMPLEMENTATION_PLAN.md)** - AI feature roadmap

**Start here if:** You need to understand product requirements, project scope, or implementation status.

---

### 🏗️ Architecture Documentation
> **How** the system is designed and structured

Technical architecture, design patterns, and system integration details.

- **[Architecture Overview](architecture/Architecture.md)** - Complete system architecture and design patterns
- **[Technical Specifications](architecture/TechnicalSpecs.md)** - Detailed technical specs
- **[LiteLLM Integration](architecture/LITELLM_API_INTEGRATION.md)** - LLM proxy integration architecture
- **[Custom LLM Integration](architecture/CUSTOM_LLM_INTEGRATION_PLAN.md)** - Multi-provider LLM design
- **[Azure OpenAI Integration](architecture/AZURE_OPENAI_INTEGRATION_PLAN.md)** - Azure AI service integration
- **[G1 Glasses Research](architecture/even_realities_g1_integration_research.md)** - Smart glasses integration research
- **[Audio Processing Research](architecture/flutter_sound_research.md)** - Audio capture and processing design
- **[Transcription Research](architecture/flutter_openai_transcription_research.md)** - Speech-to-text integration research

**Start here if:** You're working on core architecture, adding new services, or understanding system design.

---

### 🔌 API Documentation
> **Interface** definitions and integration guides

Comprehensive API references for all services and integrations.

- **[AI Services API](api/AI_SERVICES_API.md)** - Complete API reference for LLM, fact-checking, and insights services
- **[Even Realities G1 Protocol](api/EVEN_REALITIES_G1_BLE_PROTOCOL.md)** - Bluetooth protocol for smart glasses

**Start here if:** You're integrating with AI services, connecting hardware, or need API specifications.

---

### 👩‍💻 Developer Guides
> **Step-by-step** instructions for development

Hands-on guides for developers working on the codebase.

- **[Quick Start Guide](dev/QUICK_START.md)** - Get up and running in 10 minutes
- **[Developer Guide](dev/DEVELOPER_GUIDE.md)** - Comprehensive development workflows and patterns
- **[Flutter Best Practices](dev/FLUTTER_BEST_PRACTICES.md)** - Flutter coding standards and patterns
- **[Implementation Guide](dev/COMPREHENSIVE_IMPLEMENTATION_GUIDE.md)** - Detailed implementation walkthroughs
- **[AI Test Usage](dev/SIMPLE_AI_TEST_USAGE.md)** - How to test AI features locally

**Start here if:** You're developing features, fixing bugs, or contributing code.

---

### 🚀 Operations & Deployment
> **Deploy**, monitor, and maintain the system

Deployment workflows, infrastructure, and operational procedures.

- **[Build & Deploy Workflow](ops/BUILD_DEPLOY_WORKFLOW.md)** - Step-by-step iOS deployment guide
- **[Build Status](ops/BUILD_STATUS.md)** - Current build health and status
- **[Service Level Agreement](ops/SLA.md)** - Performance targets and SLA commitments

**Start here if:** You're deploying to devices, managing infrastructure, or monitoring production.

---

### 🧪 Evaluation & Testing
> **Verify** quality through comprehensive testing

Testing strategies, test reports, and quality assurance documentation.

- **[Testing Strategy](evaluation/TESTING_STRATEGY.md)** - Comprehensive testing approaches and best practices
- **[Test Report](evaluation/TEST_REPORT.md)** - Latest test results and verification
- **[Test Implementation Guide](evaluation/TEST_IMPLEMENTATION_GUIDE.md)** - How to write and run tests
- **[Test Results Summary](evaluation/TEST_RESULTS_SUMMARY.md)** - Historical test results

**Start here if:** You're writing tests, verifying features, or ensuring quality.

---

## Getting Started by Role

### 🆕 New Developer
1. Read [Quick Start Guide](dev/QUICK_START.md)
2. Review [Architecture Overview](architecture/Architecture.md)
3. Follow [Developer Guide](dev/DEVELOPER_GUIDE.md)
4. Check [Flutter Best Practices](dev/FLUTTER_BEST_PRACTICES.md)
5. Run through [Test Implementation Guide](evaluation/TEST_IMPLEMENTATION_GUIDE.md)

### 🎨 Product Manager
1. Review [Requirements](product/Requirements.md)
2. Check [Implementation Status](product/FINAL_INTEGRATION_STATUS.md)
3. Understand [AI Features Plan](product/AI_FEATURES_IMPLEMENTATION_PLAN.md)
4. Review [Test Report](evaluation/TEST_REPORT.md)

### 🏗️ Architect
1. Study [Architecture Overview](architecture/Architecture.md)
2. Review [Technical Specifications](architecture/TechnicalSpecs.md)
3. Examine [AI Services API](api/AI_SERVICES_API.md)
4. Check integration plans in [architecture/](architecture/)

### 🧪 QA Engineer
1. Follow [Testing Strategy](evaluation/TESTING_STRATEGY.md)
2. Read [Test Implementation Guide](evaluation/TEST_IMPLEMENTATION_GUIDE.md)
3. Review [Test Report](evaluation/TEST_REPORT.md)
4. Check [Build Status](ops/BUILD_STATUS.md)

### 🚀 DevOps Engineer
1. Study [Build & Deploy Workflow](ops/BUILD_DEPLOY_WORKFLOW.md)
2. Review [Build Status](ops/BUILD_STATUS.md)
3. Understand [SLA](ops/SLA.md) requirements
4. Check [Architecture](architecture/Architecture.md) for infrastructure needs

---

## Key Features Documentation

### 🎤 Audio Recording & Processing
- Architecture: [Audio Processing Research](architecture/flutter_sound_research.md)
- Developer Guide: [Developer Guide - Audio Services](dev/DEVELOPER_GUIDE.md#audio-processing-pipeline)
- Testing: [Testing Strategy - Audio](evaluation/TESTING_STRATEGY.md#audio-processing)

### 🗣️ Speech-to-Text Transcription
- Architecture: [Transcription Research](architecture/flutter_openai_transcription_research.md)
- API: [AI Services API - Transcription](api/AI_SERVICES_API.md)
- Implementation: [Implementation Guide](dev/COMPREHENSIVE_IMPLEMENTATION_GUIDE.md)

### 🧠 AI Analysis & Insights
- Architecture: [Custom LLM Integration](architecture/CUSTOM_LLM_INTEGRATION_PLAN.md)
- API: [AI Services API](api/AI_SERVICES_API.md)
- Developer Guide: [Working with AI Services](dev/DEVELOPER_GUIDE.md#working-with-ai-services)
- Testing: [AI Test Usage](dev/SIMPLE_AI_TEST_USAGE.md)

### 📱 Smart Glasses Integration
- Architecture: [G1 Integration Research](architecture/even_realities_g1_integration_research.md)
- Protocol: [Even Realities G1 BLE Protocol](api/EVEN_REALITIES_G1_BLE_PROTOCOL.md)
- Requirements: [Requirements - Hardware](product/Requirements.md#even-realities-integration-er)

---

## Documentation Standards

### When to Update Documentation
- **Before** implementing new features → Update product/requirements
- **During** implementation → Update dev guides and API docs
- **After** deployment → Update test reports and build status
- **When** architecture changes → Update architecture docs

### How to Contribute
1. Keep docs in sync with code
2. Use clear, concise language
3. Include code examples where helpful
4. Add diagrams for complex concepts
5. Update this index when adding new docs

### Documentation Owners
- **Product Docs** → Product Team
- **Architecture** → Engineering Leads
- **API Docs** → Service Owners
- **Dev Guides** → Development Team
- **Operations** → DevOps Team
- **Testing** → QA Team

---

## Quick Links

### External Resources
- **[Linear Project Board](https://linear.app/art-jiang/project/helix-real-time-transcription-and-fact-checking-4ac9c858372e)** - Issue tracking and roadmap
- **[GitHub Repository](https://github.com/FJiangArthur/Helix-iOS)** - Source code and releases
- **[Flutter Documentation](https://docs.flutter.dev)** - Flutter framework docs
- **[Riverpod Guide](https://riverpod.dev)** - State management documentation

### Related Documentation
- **[Main README](../README.md)** - Project overview and key features
- **[Contributing Guidelines](../README.md#contributing)** - How to contribute

---

## Feedback & Improvements

Found an issue or have suggestions for improving documentation?
- Open an issue on GitHub
- Submit a pull request with improvements
- Contact the documentation team

---

**Last Updated**: 2025-11-16
**Documentation Version**: 1.0
**Project**: Helix AI Conversation Intelligence

*For questions or help navigating documentation, please reach out through GitHub Issues or the Linear project board.*
