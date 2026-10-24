# 🔄 Automatic LLM Fallback

## Overview

Hermes is configured with **native automatic fallback** to ensure continuous operation even when the primary model experiences issues. The system automatically switches between models without losing conversation context.

## Model Configuration

**Primary model**: Mistral Large 4 (`mistralai/mistral-large-4-0`)  
**Automatic fallback**: GLM-5.3 Flash (`z-ai/glm-5.3-flash`)

The fallback is **per-turn**: each new message attempts the primary first; if it fails again, the fallback activates for that turn only.

## When Fallback Activates

The automatic fallback triggers when Mistral Large 4 encounters:
- **Rate limits** (HTTP 429) — OpenRouter has tight limits: 20 req/min, 50-1000 req/day
- **Server errors** (HTTP 500, 502, 503) — after retry attempts exhausted
- **Auth failures** (HTTP 401, 403) — immediately

## Model Comparison

Both models have the **same Cyber Index score (50%)** but different trade-offs:

| Aspect | Mistral Large 4 | GLM-5.3 Flash |
|--------|-----------------|---------------|
| **Cyber Index** | 50% | 50% (same) |
| **Cost** | $1.36/M in, $4.18/M out | $0.07/M in, $0.21/M out (20x cheaper) |
| **CyberGym** | ~74% | 84.5% (top score) |
| **NexBench** (real pentest) | — | 29/100 (autonomous long engagement) |
| **Production proof** | Corporate-tested | End-to-end exploits, 0-days, Hugging Face incident |
| **Multimodal** | No | Yes (screenshots, PDFs) |
| **Context** | 1M tokens | 1M tokens |
| **Safeguards** | Robust | Bypassable (advantage in authorized pentests) |

## Prompt Cache Behavior

⚠️ **Important**: When fallback activates, the new model has no cached conversation prefix, so the next request re-reads the entire history at full input-token price (not the 75-90% cached discount). This also applies when returning to the primary. It's the cost of staying alive through an outage.

## Manual Override

To use GLM-5.3 Flash as the **primary** (instead of waiting for automatic fallback):

### Before starting the stack

Set in `.env`:
```sh
OPENROUTER_MODEL=z-ai/glm-5.3-flash
```

### Change it live in a running container

```sh
docker compose exec ooda-agent hermes config set model.default z-ai/glm-5.3-flash
```

## Configuration Details

Configuration is managed in [`agent-ooda/profile/config.yaml`](../agent-ooda/profile/config.yaml) (see `fallback_providers` section).

## Full Model Analysis

See [`docs/modelos-cyberseguridad-openrouter-CORRECTED.md`](modelos-cyberseguridad-openrouter-CORRECTED.md) for the complete analysis of cybersecurity-focused models on OpenRouter.
