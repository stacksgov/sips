# Contributing to the SIPs Repository

This document describes the working practices for this repository. It documents
how we apply the SIP process defined in
[SIP-000](./sips/sip-000/sip-000-stacks-improvement-proposal-process.md).
It does not add to or override SIP-000. Where this document and SIP-000
disagree, SIP-000 wins.

These practices can be improved through a regular pull request to this file.

## Submitting a SIP

- Fork this repository and open your SIP as a pull request from your fork.
  Do not create branches in this repository.
- Follow the [SIP template](./sips/SIP_TEMPLATE.md) for structure and
  preamble fields. Your SIP starts in Draft status and without a number.
  A SIP Editor assigns the number when the SIP moves to Accepted.
- Write in plain language. Marketing or promotional material does not belong
  in the SIP text. Supporting material can be added as supplemental documents
  per SIP-000.

Before submitting, it helps to socialize your idea. A post on the
[Stacks forum](https://forum.stacks.org), a discussion on a SIP call, or
feedback from a relevant working group will surface problems early. None of
these are required, but SIPs that skip them tend to spend longer in review.

## Review etiquette

- Authors should not resolve review comments on their own SIP unless they
  made a change that addresses the comment or explain why no change is
  needed. Resolution should be visible to reviewers and CAB members.
- Reviewers should give feedback that the author can act on, and give it
  in a timely manner, in the spirit of SIP-000's "fair and speedy
  good-faith consideration".

## Workflow on GitHub

SIP-000 defines the statuses. In this repository they map to the following
actions:

1. **Draft**: the SIP is an open pull request. SIP Editors and the community
   give feedback in the PR.
2. **Accepted**: a SIP Editor verifies the SIP is well-formed, assigns the
   number, adds their sign-off, and the SIP is committed to the repository
   so CABs can review it.
3. **Recommended**: the relevant Consideration Advisory Boards review the
   SIP, publish their minutes (as a separate PR), and add their sign-off.
4. **Activation-in-Progress**: the Steering Committee votes and adds their
   sign-off. The SIP's own Activation section now governs what happens.
5. **Ratified** or **Rejected**: the Steering Committee determines the outcome
   from the Activation criteria and updates the status. For SIPs activated
   by a vote, the results and how they were verified are recorded with the SIP.

## SIP numbers and status labels

- SIP numbers are assigned once and never reused, even if the SIP never
  advances past Draft. This prevents one number from referring to two
  different proposals. Numbers need not be assigned in chronological order,
  and gaps in the numbering (such as 011, 014, 017) stay as they are.
- **Withdrawn Draft** is used in the README and SIP tables as a label for a
  SIP that received a number but was abandoned before reaching Accepted
  status. It is a display convention, not a SIP-000 status: SIP-000 defines
  Withdrawn for SIPs whose authors ceased work after entering the process,
  and this label makes clear the SIP never got past the Draft stage.

## After a CAB vote

Once a CAB has voted, the SIP is approved in its voted form. Editorial fixes
that do not change the meaning of the text may still be made before merge,
and any such change must be visible in the PR. If any CAB member believes a
change alters the meaning, the CAB votes again. CABs may adopt this rule in
their own bylaws per SIP-000.

## Merging

Merge authority rests with the Steering Committee or its appointees, per
SIP-000. In practice a SIP PR merges when the sign-offs for its current
status are in place: the Editor sign-off at Accepted, CAB sign-offs and
minutes at Recommended, and Steering Committee sign-off from
Activation-in-Progress onward.

## Updating a ratified SIP

A ratified SIP is not edited, except to fix errata or add supplemental
material. Substantial changes require a new SIP that replaces the old one,
as defined in SIP-000:

- The new SIP contains the complete text, goes through the normal process,
  and receives the next free SIP number like any other SIP.
- The new SIP lists `Replaces:` in its preamble. Once ratified, the old SIP's
  status becomes Replaced and it receives a `Superseded-By:` field.
- The replaced SIP keeps its number, filename and location, so existing links
  keep working. Besides the preamble update, a notice is added at the top of
  the replaced SIP pointing to its replacement:

  > [!IMPORTANT]
  > This SIP has been replaced by [SIP-XYZ](./link-to-new-sip.md).  

This also applies to SIP-000 itself.
