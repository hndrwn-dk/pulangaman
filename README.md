# PulangAman

PulangAman is a community safety app for parents and children in Indonesia. It helps families stay connected on the way home from school with live location awareness, trusted-circle alerts, and practical tools that keep guardians in the loop without exposing children to strangers.

## Features

- Live location sharing between parent and child
- Home and school zones with arrival awareness
- Panic alerts routed only to pre-approved guardians
- School attendance signals for partner schools
- Community safety reports near common routes
- Optional rewards and screen-time support for families

## Tech Stack

- **Mobile:** Flutter (Android & iOS)
- **Backend:** Node.js + Express
- **Data:** PostgreSQL (PostGIS), Redis
- **Realtime:** WebSocket updates for live awareness

## Getting Started

This repository is a monorepo:

| Path | Purpose |
|------|---------|
| `apps/mobile` | Flutter client |
| `services/api` | HTTP/WebSocket API |

You will need Node.js 20+, Flutter 3.x, and Docker for local infrastructure. See each package README for setup details.
