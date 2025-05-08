# AI SDK Test Implementation Plan

This file contains all the tests we need to implement for the Elixir AI SDK, based on the Vercel AI SDK's test suite.

## Generate Text Tests

- [x] **Basic Text Generation**
  - [x] Generate simple text (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:79-109`)

- [x] **Reasoning Features**
  - [x] Get reasoning string from model response (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:111-122`)

- [x] **Sources Handling**
  - [x] Verify sources are present in response (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:124-133`)

- [x] **File Handling**
  - [x] Verify files are included in response (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:135-144`)

- [ ] **Steps Tracking**
  - [ ] Track reasoning in step results (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:146-161`)
  - [ ] Track sources in step results (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:163-175`)
  - [ ] Track files in step results (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:177-189`)

- [x] **Tool Calls**
  - [x] Handle basic tool calls (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:192-275`)
  - [x] Type inference for tool calls (Note: Elixir requires different approach for type checking)

- [x] **Tool Results**
  - [x] Process and return tool results (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:278-349`)
  - [x] Type inference for tool results (Note: Elixir requires different approach for type checking)

- [x] **Provider Metadata**
  - [x] Include provider metadata in response (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:352-376`)

- [x] **Response Message Handling**
  - [x] Include assistant messages with no tool calls (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:378-392`)
  - [x] Include assistant and tool messages when there are tool calls (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:394-435`)
  - [x] Include reasoning in messages (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:437-446`)

- [ ] **Request/Response Info**
  - [ ] Include request body (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:448-467`)
  - [ ] Include response body and headers (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:469-496`)

- [ ] **Multi-step Processing**
  - [ ] Handle 2-steps: initial + tool result (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:498-691`)
  - [ ] Handle 2-steps with prepareStep (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:693-894`)
  - [ ] Handle 4-steps: initial + multiple continues (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:896-1183`)

- [x] **HTTP Headers**
  - [x] Pass headers to model (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1186-1207`)

- [x] **Provider Options**
  - [x] Pass provider options to model (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1209-1229`)

- [ ] **Abort Signal**
  - [ ] Forward abort signal to tool execution (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1231-1274`)

- [ ] **Telemetry**
  - [ ] Skip telemetry when not enabled (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1276-1296`)
  - [ ] Record telemetry when enabled (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1298-1334`)
  - [ ] Record successful tool calls (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1336-1368`)
  - [ ] Skip recording telemetry inputs/outputs when disabled (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1370-1406`)

- [ ] **Custom Schemas**
  - [ ] Handle tools with custom JSON schema (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1408-1505`)

- [ ] **Message Handling**
  - [ ] Detect and convert UI messages (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1507-1583`)
  - [ ] Support models with context in supportsUrl (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1585-1619`)

- [ ] **Output Handling**
  - [ ] Throw error when accessing output without specification (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1621-1638`)
  - [ ] Handle text output (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1640-1687`)
  - [ ] Handle object output without structured output model (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1689-1751`)
  - [ ] Handle object output with structured output model (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1753-1816`)

- [ ] **Error Handling**
  - [ ] Handle tool execution errors (`/vercel-ai-sdk/packages/ai/core/generate-text/generate-text.test.ts:1818-1855`)

## Stream Text Tests

- [x] **Basic Text Generation Streaming**
  - [x] Initialize a basic text stream with mock model
  - [x] Stream text from OpenAI provider
  - [x] Handle streaming errors gracefully
  - [x] Stream with system message correctly

- [x] **Server-Sent Events (SSE) Implementation**
  - [x] Initialize an SSE stream with proper HTTP headers
  - [x] Parse SSE events correctly (data, event, id fields)
  - [x] Handle multi-line data in SSE events
  - [x] Process JSON content in SSE data fields
  - [x] Support error handling and stream cancellation

- [ ] **Advanced Streaming Features**
  - [ ] Stream with tool calls and function calling
  - [ ] Handle streaming cancellation
  - [ ] Implement backpressure handling
  - [ ] Support for structured output streaming