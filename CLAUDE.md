# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the Stacks Improvement Proposals (SIPs) repository - a governance documentation repository for the Stacks blockchain. It contains proposals for changes to the blockchain's design, implementation, operation, and governance.

**This is NOT a code repository.** It is a collection of markdown documents following a formal proposal and ratification process.

## Repository Structure

- `sips/` - Contains all SIP documents organized by number (e.g., `sip-000/`, `sip-001/`)
- `considerations/` - Contains Consideration Advisory Board (CAB) information and meeting minutes
- `sips/SIP_TEMPLATE.md` - Template for new SIP submissions

## SIP Document Format

All SIPs are markdown files with required sections in order:
1. **Preamble** - Metadata fields (SIP Number, Title, Author, Consideration, Type, Status, Created, License, Sign-off)
2. **Abstract** - High-level summary (max 5000 words)
3. **Copyright** - License information
4. **Introduction** - Problem description and proposed solution
5. **Specification** - Detailed technical specification
6. **Related Work** - Alternative solutions and bibliography
7. **Backwards Compatibility** - Breaking changes and mitigations
8. **Activation** - Timeline, criteria, and process for activation
9. **Reference Implementation** - Links to implementations

## SIP Types

- **Consensus** - Requires all implementations to adopt (hard/soft fork)
- **Standard** - Affects implementations but not consensus
- **Operation** - Concerns node operators and miners
- **Meta** - Changes to the SIP process itself
- **Informational** - Provides information without requiring action

## SIP Considerations (Review Tracks)

- **Technical** - Technical expertise review
- **Economic** - Token economics, fundraising, grants
- **Governance** - SIP process and committee structure
- **Ethics** - Behavioral standards for office-holders
- **Diversity** - User growth and outreach

## SIP Workflow

Draft → Accepted → Recommended → Activation-In-Progress → Ratified

SIPs can also be: Rejected, Obsolete, Replaced, or Withdrawn

## Working with SIPs

When creating or editing SIPs:
- Follow the template in `sips/SIP_TEMPLATE.md`
- Place SIP files in `sips/sip-XXX/sip-XXX-title.md`
- Supplementary materials go in the same directory as `SIP-XXXX-YYY.ext`
- Use approved licenses: BSD-2-Clause, BSD-3-Clause, CC0-1.0, GNU-All-Permissive, GPL-2.0+, LGPL-2.1+
