---
title: Discovery questionnaire
description: An interactive workshop questionnaire that turns Azure Virtual Desktop discovery answers into reference architecture recommendations, readiness gaps and pilot deployment parameters.
---

# Discovery questionnaire

!!! abstract "At a glance"
    - Use this page with a customer during discovery workshops to capture the decisions that shape a pooled Azure Virtual Desktop pilot.
    - The questionnaire recommends reference architecture patterns, highlights dependencies, estimates first-pass sizing and builds a pilot parameters file.
    - It is browser-only. Answers are stored in localStorage in this browser and are not sent to a server.
    - Export the answers and report at the end of the workshop, then attach them to the project record.

## How to run a discovery workshop with it

1. Open this page in the workshop and share the screen.
2. Work through the sections with the relevant owners: platform, identity, endpoint management, applications, network, security, operations, cost and governance.
3. Treat the live outputs as a conversation guide, not as a final design. The sizing numbers are estimates and must be validated in a pilot.
4. Export the answers, the Markdown report and the generated **azuredeploy.parameters.json** before closing the browser.
5. Use the recommendations to choose the North Star path and any time-bound stepping stones.

## Privacy

The questionnaire runs in the browser with vanilla JavaScript. It does not use frameworks, external scripts, CDNs, analytics or external service calls. Answers persist only in this browser's localStorage until you reset them, clear browser data or import a different answers file. Exported files are created locally by the browser.

## Questionnaire

<div
  data-discovery-questionnaire
  data-site-root="../../"
  data-questionnaire-src="assets/discovery/questionnaire.json"
></div>
