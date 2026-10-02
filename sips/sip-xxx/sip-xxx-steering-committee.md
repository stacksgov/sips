# Preamble

SIP Number: XXX

Title: Steering Committee Membership and Governance Process

Author: Jesse Wiley <jesse@stacks.org>, Marvin Janssen <marvin@ryder.id>

Consideration: Governance

Type: Meta

Status: Draft

Created: 2026-09-30

License: BSD-2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

Requires: 000

# Abstract

This SIP defines a formal governance process for the Stacks Improvement Proposal
(SIP) Steering Committee (SC). Specifically, it establishes rules governing the
composition of the SC, including the number of active and alternate members,
qualifications for membership, the process by which new members may be nominated
and seated, the conduct of all SC correspondence, and the framework by which SC
members may be compensated for their service. The intent of this SIP is to
ensure that the SC remains accountable, adequately staffed, and capable of
fulfilling its duties as described in SIP-000, while maintaining continuity of
governance across member transitions.

# License and Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP's copyright
is held by the Stacks Open Internet Foundation.

# Introduction

SIP-000 established the Steering Committee (SC), but does not fully specify many
of the operational details that govern how the SC itself is constituted and
maintained over time. In particular, SIP-000 leaves open questions regarding how
many members should comprise the SC, how vacancies are filled, how nominations
are made, what communication channels govern SC business, and whether or how
members may receive compensation.

This SIP attempts to address some of these gaps in SIP-000. The proposed
process:

- Prioritizes transparency (by requiring all correspondence to be conducted via
  a public mailing list).
- Accountability (through a restricted but clearly defined nomination process)
- Continuity (through the provision of alternate members who may vote in the
  absence of active members).

This SIP does not (and shall not be construed to) grant new powers to the SC
over and above those defined in SIP-000 or change the current member
composition.

# Specification

## Steering Committee Composition

### Active Members

The Steering Committee (SC) shall at all times consist of exactly three (3)
active, voting members. Active members bear the full duties and responsibilities
of the SC as described in SIP-000, including attending public meetings, voting
on SIPs, recognizing Consideration Advisory Boards, overseeing SIP activation
and ratification, and other activities that may be defined in future SC bylaws.

### Alternate Members

The Steering Committee shall maintain a roster of exactly two (2) alternate
members. Alternate members are non-voting participants in SC proceedings under
normal circumstances, but are empowered to vote in place of an active member
under specific circumstances as defined later in the document.

Alternate members are expected to remain informed of all ongoing SC business,
attend public meetings as observers, and be prepared to assume an active
membership seat when one becomes vacant.

### Support Roles: Moderators and Note-takers

The Steering Committee may appoint moderators and note-takers to assist them in
their official duties.

Moderators manage SC meetings, community calls, and so on, and ensure that they
are conducted in an orderly fashion.

Note-takers attend SC meetings to take note of the discussion and produce
official meeting minutes.

## Qualifications

The qualifications for SC membership shall remain as defined in SIP-000. For
reference, all candidates for active or alternate SC membership:

- Must possess deep domain expertise pertinent to blockchain development;
- Must possess excellent written communication skills; and
- Should have authored at least one ratified technical-consideration SIP prior
  to joining the committee.

All SC members must abide by the SIP Code of Conduct at all times. Failure to
adhere to the Code of Conduct shall be grounds for immediate removal from the
SC, with no eligibility to rejoin any SC seat until the matter has been formally
reviewed and resolved per the relevant Ethics-consideration SIP or, in the
absence of such a SIP, at the SC's unanimous discretion (excluding the affected
member).

## Steering Committee Duties and Powers

The duties and powers of the SC shall remain as defined in SIP-000, with some
clarifications and exceptions added in this section.

### Quorum

A quorum for the purpose of conducting official SC business shall be any two (2)
of the three (3) active members, or any combination of active and alternate
members that results in at least two (2) eligible voters being present. The only
exception is when the SC votes on a Consensus-type SIP for a hard fork. Three
voting members shall be required in such cases.

Alternate members shall only be empowered to vote in place of an active member
under the following conditions:

- An active member provides advance written notice that they will be absent from
  a scheduled meeting or vote and fails to provide a written vote for the
  meeting.
- An active member is unresponsive for a period of fourteen (14) or more
  consecutive calendar days during an active deliberation or vote.
- An active member has formally vacated their seat, and a successor has not yet
  been seated.
- An active member is under review for failing to adhere to the SIP Code of
  Conduct.
- An active member is under review as part of the removal process defined later
  in this document.

When an alternate member votes in place of an active member, this shall be
recorded in the meeting minutes and published. In no case shall there be more
than three (3) total votes cast in any SC deliberation. The method by which an
alternate may be required to cast a vote shall be chosen by the active SC
members on a case by case basis. (For example: the first alternate who affirms
their willingness to participate.) The SC may adopt bylaws to further define the
selection process.

### Voting on Technical and Non-technical SIPs

The Steering Committee shall select Recommended SIPs for ratification by moving
them to Activation-In-Progress status. Technical and Non-technical SIPs require
a two-thirds majority vote. In the case of 3 voting members, 2 votes in favour
are required. In case of 2 voting members, both members must vote in favour.

### Voting on Consensus-type SIPs for a hard fork

Full participation of the SC members shall be required and their vote must be
unanimous. Three votes must be cast and they must all be in favour in order to
move the SIP to Activation-in-Progress status.

## Correspondence and Public Communication

### Public Mailing List

All official SC correspondence shall be conducted via a designated public
mailing list. This includes, but is not limited to:

- Deliberations and votes on SIPs in Recommended status;
- Discussions regarding the recognition or rescission of Consideration Advisory
  Boards
- Nomination and seating of new SC members (active or alternate)
- Notices of member absences and alternate member substitutions
- Announcements of public meeting schedules and agendas
- Publication of meeting minutes
- Any formal communications between the SC and Consideration Advisory Boards,
  SIP Editors, or the Stacks Open Internet Foundation.

The Stacks Open Internet Foundation shall provision and maintain the public
mailing list infrastructure:

- The mailing list archive shall be accessible to the public in read-only form.
- Any member of the public may subscribe to the mailing list as an observer.
- Posting rights shall be limited to SC members (active and alternate), the SC's
  designated moderators and note-takers, the Stacks Open Internet Foundation (in
  case they need to post a nomination), and, at the SC's discretion, other
  formally recognized parties (e.g., Consideration Advisory Board chairpersons).

### Prohibition on Private Deliberation

No binding SC vote or formal decision may be made via private or semi-private
communication channels. Any deliberation that begins in a private channel must
be re-initiated and concluded on the public mailing list before a binding vote
may take place. This requirement does not preclude informal pre-deliberation
discussions among members, but such discussions shall not substitute for the
required public process.

### Meeting Minutes

The SC's appointed note-taker shall publish complete meeting minutes to the SIPs
public repository within five (5) business days following each public meeting.
Minutes shall include a record of attendance (including any alternate member
substitutions), all motions raised, votes cast (including individual member
votes), and any action items assigned.

## SC Membership Nomination Process

### Eligibility to Nominate

Nominations for active or alternate SC membership may be submitted only by the
following parties:

- Any current SC member (excluding alternates).
- The Stacks Open Internet Foundation Board (acting by unanimous vote of its own
  membership).

SC members may make full use of the community to source potential candidates.
However, the above parties alone retain the ability to nominate.

To prevent conflicts of interest and to adhere to existing governance standards,
self-nominations are not permitted. No individual may be nominated by more than
one nominating party per vacancy. If multiple nominations are received for the
same vacancy, the SC shall evaluate all nominees and select the most qualified
candidate by a two-thirds majority vote.

### Nomination Procedure

When a SC seat becomes vacant, the SC shall notify the public mailing list
within seven (7) calendar days of the vacancy arising. The notification shall
describe the nature of the vacancy (active or alternate), the anticipated
timeline for filling it, and an invitation for eligible nominators to submit
candidates.

Nominations shall be submitted to the public mailing list and shall include:

- The full name and contact information of the nominee.
- A statement of the nominee's qualifications relative to those defined in
  SIP-000 and reiterated in this SIP.
- A brief description of why the nominating party believes the nominee is suited
  to serve on the SC.
- Written confirmation from the nominee that they accept the nomination, are
  aware of the responsibilities of the role, and agree to abide by the SIP Code
  of Conduct. The nominator shall post the written confirmation to the public
  mailing list.

The nomination window shall remain open for no fewer than fourteen (14) calendar
days, and will remain open until the vacancy is filled. If there are no
nominations after thirty (30) days, then the SC shall re-post the vacancy on the
public mailing list in a bid to continue to solicit nominations.

### Seating Body

Following the close of the nomination window, a Seating Body shall be formed to
jointly deliberate and vote to seat one nominee per vacancy. The Seating Body
shall consist of an equal number of:

- SC members; and,
- Voting members of the Stacks Open Internet Foundation Board.

The Seating Body shall consist of no fewer than four (4) members and no more
than six (6) members. Both parties shall supply an equal number of members, and
three (3) members at most. If, for any reason, either side cannot supply the
maximum permitted number of members, then members of the other party must recuse
themselves so that both parties are equally represented in the Seating Body.
(For example, if the SC supplies two (2) members, then the Stacks Open Internet
Foundation board shall also supply (2) members.)

Alternate SC members may only be part of the Seating Body if they are empowered
to vote per the rules of this SIP. Any nominees that are also a member of the
Stacks Open Internet Foundation Board shall not be eligible to serve on the
Seating Body.

Members of the Seating Body may only withdraw if an immediate substitute is
available. The Seating Body shall automatically dissolve when the Nomination
Procedure is concluded.

### Evaluation and Seating

The Seating Body shall deliberate publicly and vote to seat one nominee per
vacancy. Each member of the Seating Body shall be entitled to cast one (1) vote.
The vote to seat a nominee shall require a two-thirds majority.

Voting members will independently assess the nominee on their merits and may
vote at any point during the thirty (30) day voting window. Members that fail to
vote within the voting window will be recorded as a no-vote. The vote ends
immediately once all members have voted or the voting window has passed.

If no nominee receives the required two-thirds majority vote, then no seating
shall occur for that vacancy, and the nomination window shall remain open (or be
re-opened) per the Nomination Procedure until the vacancy is filled.

Once a nominee is voted into a seat, the SC shall announce the seating decision
on the public mailing list and update the SC's public member roster accordingly.
The newly seated member's term shall begin on the date of the seating
announcement.

### Promotion of Alternate Members

When an active member seat becomes vacant, the SC should, as a matter of first
recourse, consider whether one of the existing alternate members is qualified
and willing to be promoted to the active seat. If so, the SC may vote to promote
an alternate member to the active seat without opening a full nomination window,
provided that the promotion vote satisfies the two-thirds majority threshold.
The resulting vacancy in the alternate roster shall then be filled through the
standard nomination process. Only a single alternate may be promoted during any
six (6) month timeframe from the last alternate member promotion, with the
requirement that the promoted SC member has remained active since being
promoted.

## Resignation of SC members

SC members may resign at any time. They must do so by writing to the public
mailing list. The remaining SC members shall endeavor to fill the vacancy as
soon as they are able by means of the nomination procedure described above.

## Removal of SC members

SC members, both actives and alternates, shall be subject to removal under the
following circumstances.

1. The SC member failed to adhere to the SIP Code of Conduct.
2. The SC member deliberately misrepresented themselves in order to meet the
   qualifications.
3. The SC member has been unresponsive or inactive for a period of thirty (30)
   or more days, has not provided advance written notice that they will be
   absent, and did not empower an alternate to vote in their stead.
4. The SC member failed to cast a vote for three (3) successive deliberations.
   (Abstaining shall not be counted as a failure to cast a vote.)
5. The SC member demonstrably violated the rules on the prohibition of private
   deliberation or the principles laid out in the Compensation section.
6. The SC member demonstrably acted or intended to act beyond the powers and
   capabilities of the SC.

For the avoidance of doubt: "unresponsive" is understood as not participating in
the public mailing list when called upon. "Inactive" means not participating in
public sessions or deliberations where SC members are normally expected. An SC
member shall not be considered unresponsive or inactive if they have given prior
notice and followed the correct procedures to empower an alternate.

## SC Member Removal Process

### By the SC

If the SC identifies a member subject to removal, they shall publish their
intent to the public mailing list. The notice must cite at least one of the
removal conditions mentioned above and must include a body of evidence to
support their claim. Active members as well as alternates may publish an intent
to vote for removal. However, an alternate member should first report their
findings to an active member so they may publish the intent. The intent must be
public for at least seven (7) days, after which the SC shall vote to remove the
offending SC member by a two-thirds majority. The offending member shall not be
entitled to a vote. If the offending member is an active member, then an
alternate member will be empowered to vote.

It must be clear that the SC, under no circumstance, shall be able to vote to
remove an SC member if that member did not meet any of the removal conditions.

### By the Governance CAB, Ethics CAB, and Stacks Open Internet Foundation

If it is found that the SC can no longer reach a quorum to conduct business,
then a failsafe procedure may be enacted in order to restore the SC to working
order.

#### Failsafe conditions

The failsafe may only be activated if all of the following conditions are met:

1. The active SC members fail to reach a quorum, regardless of the reasons.
2. The alternative SC members are unable to be empowered in order to reach the
   quorum and vote because they themselves are inactive or the seats are vacant.
3. The SC fails to reach a quorum for over thirty (30) days.
4. The CABs and Stacks Open Internet Foundation Board made a good-faith attempt
   to reach out to the SC members, active and alternate, to instruct them to
   remedy the situation.

#### Failsafe Procedure

The failsafe procedure can be activated by the following parties, but must do so
in order:

1. Governance CAB
2. Ethics CAB
3. Stacks Open Internet Foundation, acting as a backstop

If a party fails to activate the failsafe procedure within seven (7) days
(because for example, there is a problem internal to the party), then the next
party in line may do so. The next party must demonstrate that the previous party
failed to activate the failsafe when it should have done so.

The party activating the failsafe shall deliberate in a manner appropriate to
them and then vote to remove one or more offending SC members. If the party is a
CAB, then they must pass the resolution with a two-thirds majority vote. If the
party is the Stacks Open Internet Foundation, then they shall publish their
decision on the public mailing list and any other public platform they may use.

## Inoperability due to resignation or failsafe procedure

The SC may be left inoperable due to sudden resignations or by means of the
failsafe procedure. If the SC is left with one (1) or zero (0) members at any
point, then the Stacks Open Internet Foundation shall appoint provisional SC
members such that the total SC membership is restored to exactly three (3)
members. These provisional members shall then immediately nominate and vote for
new members to replace them. The provisional SC members will be considered to
have resigned as soon as a replacement has been found for each of them.
Provisional SC members cannot nominate nor vote for each other.

## Compensation

### Scope

This SIP establishes a framework for SC member compensation but does not itself
prescribe specific compensation amounts or funding sources. Specific
compensation arrangements shall be documented in supplemental materials ratified
alongside or subsequent to this SIP, and may be revised by a subsequent
Governance-consideration SIP or by agreement of the Stacks Open Internet
Foundation Board.

### Eligibility

All active SC members are eligible for compensation for the time they dedicate
to carrying out their SC duties. Alternate members are eligible for compensation
when actively substituting for an absent active member, and for their ongoing
participation in SC business as observers and in preparation for potential
activation. Moderators and note-takers appointed by the SC are separately
eligible for fixed, regular bounties as described in SIP-000.

### Principles

Any compensation structure adopted under this SIP shall adhere to the following
principles:

- **Transparency.** All compensation arrangements, including amounts, payment
  schedules, and funding sources, shall be published on the SC's public mailing
  list and maintained as supplemental documentation to this SIP.
- **Consistency.** All active members serving concurrently shall receive equal
  compensation for equivalent duties.
- **Non-conflicting.** Compensation arrangements shall not create financial
  incentives that conflict with the SC's duty to act in the best interests of
  the broader Stacks user community. SC members who identify a potential
  compensation-related conflict of interest in relation to a particular SIP vote
  shall recuse themselves from that vote and notify the public mailing list.
- **Foundation-backed.** Compensation shall be sourced from the Stacks Open
  Internet Foundation or from a funding mechanism ratified by the SC by means of
  successfully adopting bylaws. No SC member shall accept compensation from any
  external party in connection with their SC duties without the unanimous
  written consent of the other active SC members, published to the public
  mailing list.

## Bylaws

The SC may adopt bylaws by means of a two-thirds majority vote. Such bylaws
shall only have effect if they are limited to changes of the following nature:

- The selection process by which the SC empowers an alternate member to vote.
- The duties and responsibilities of moderators and note-takers.
- The means by which the SC corresponds publicly. (For example, if the mailing
  list becomes unavailable.)
- How and when SC members are compensated. This allows the SC to accept funding
  proposals from other entities without requiring a SIP. Adopting bylaws that
  involve SC compensation shall require unanimous approval.
- The parties able to activate the failsafe procedure, if one or more of these
  parties become unavailable.

Any other matters are reserved and shall only be changed by means of a future
SIP. SC members that endeavour to adopt SC bylaws that are out of scope are
immediately subject to removal.

### Bylaw Adoption Process

Proposed bylaws may only be submitted by active SC members. The submitting
member shall post the full text and vote record to the public mailing list.
Active members and alternates that have been empowered to vote may cast their
vote at any time.

Proposals shall stay open for no less than seven (7) days. Bylaws may only be
adopted if the receive a two-thirds majority vote. Members that fail to vote
within the voting window will be recorded as a no-vote. The vote ends
immediately once all members have voted or the voting window has passed.
Proposed bylaws that receive unanimous support may be adopted immediately.

### Challenging proposed bylaws

Proposals may be challenged if they are deemed to be in contravention of this
SIP or SIPs and bylaws that are adopted in the future. A succesful challenge
will strike down the proposal, after which it may be revised and resubmitted as
another bylaw proposal or a SIP.

#### Challenge Procedure

Only the Governance CAB, Ethics CAB, and Stacks Open Internet Foundation may
challenge proposed bylaws. The aforementioned parties may challenge proposed
bylaws during the voting window or newly-adopted bylaws within the first
fourteen (14) days of adoption.

Bylaws that are challenged are be suspended for the duration of the challenge,
which shall be no more than fourteen (14) days. The challenging party shall
deliberate in a manner appropriate to them and render a verdict within this
window.

The verdict shall either strike the bylaws down or find that they are in fact
not in contravention. If they are struck down, then the bylaws are void. The
challenge, deliberation, and verdict shall be posted to the public mailing list.

A challenge may also separately trigger the removal process for the SC member
that proposed the bylaws. It shall be indicated in the challenge verdict if this
is the case. SC members cannot be removed by virtue of a successful bylaw
challenge. The removal process defined in this SIP must be followed in all
cases.

# Related Work

This SIP builds directly upon SIP-000, which established the Steering Committee
and defined its duties, voting thresholds, and relationship to other governance
bodies in the Stacks ecosystem.
https://github.com/stacksgov/sips/blob/main/sips/sip-000/sip-000-stacks-improvement-proposal-process.md#related-work

# Backwards Compatibility

This SIP modifies the governance structure of the Steering Committee as
established by SIP-000 and is therefore backwards-incompatible with any SC
compositions or practices that do not conform to the rules herein. The SC shall
take steps to achieve the composition defined in this SIP (three active, two
alternate members) within ninety (90) days of activation.

# Activation

This SIP shall be considered activated once all of the following criteria have
been met:

1. The SC has voted to move this SIP from Recommended status to
   Activation-In-Progress status, by the two-thirds majority threshold
   applicable to non-technical SIPs as defined in SIP-000.
2. The Stacks Open Internet Foundation has provisioned a public mailing list for
   SC correspondence and confirmed its availability in writing on that mailing
   list.
3. The SC has published a public notice on the mailing list acknowledging the
   activation of this SIP and describing the steps it will take to achieve the
   required membership composition within the ninety (90) day transition window.
4. The SC has published an updated public member roster reflecting the current
   composition of the SC (active and alternate members), including each member's
   seat start date.

Upon activation, the SC shall have ninety (90) days to achieve full compliance
with the membership composition requirements of this SIP (three active members,
two alternate members), using the nomination process defined herein. Progress
shall be reported on the public mailing list no less than once per month during
the transition period.

If the SC is unable to achieve full compliance within ninety (90) days, it shall
publish a detailed explanation on the public mailing list and request guidance
from the Stacks Open Internet Foundation Board, which may grant a one-time
extension of up to sixty (60) additional days. If that fails, then the SC
members are in contravention and subject to removal per the procedure outlined
in this SIP.

# Reference Implementations

Not applicable.
