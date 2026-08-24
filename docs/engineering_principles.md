# HDC Engineering Principles

## 1. Consistency Over Cleverness

Prefer predictable architecture over shortcuts.

---

## 2. One Responsibility Per Class

Each class should have one clear purpose.

---

## 3. Features Never Depend On Other Features Directly

Communication happens through services or the Event Bus.

---

## 4. Providers Never Perform Networking

Providers use repositories.

Repositories use ApiClient.

---

## 5. Every Entity Deserves A Passport

Employees

Stores

Assets

Products

Suppliers

Vehicles

Everything.

---

## 6. Audit Everything

Enterprise software must be traceable.

---

## 7. Timeline Everything

Every important action should become an event.

---

## 8. Nexus Understands Everything

New modules should expose enough information for Nexus AI to analyze them.

---

## 9. Build Once, Reuse Everywhere

Reusable widgets and services are preferred over duplicated code.

---

## 10. Think Enterprise

Every decision should support long-term scalability.