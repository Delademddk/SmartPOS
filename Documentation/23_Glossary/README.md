# SmartPOS — Glossary

**Document ID:** DOC-GL-023  
**Version** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This glossary defines all **business terms**, **technical terms**, and
**abbreviations** used throughout the SmartPOS documentation. It serves as a
single source of truth for terminology, ensuring consistency across all
documents.

---

## 2. Business Terms

| Term | Definition |
|------|------------|
| **Point of Sale (POS)** | The point at which a customer completes a transaction and pays for goods or services. |
| **Inventory** | The goods and materials a business holds for the purpose of resale or production. |
| **Stock Quantity** | The current number of units of a product available in inventory. |
| **Low Stock Threshold** | A per-product setting; when `stock_quantity` falls to or below this value, a notification is triggered. |
| **Sale** | A completed transaction where one or more products are sold to a customer. |
| **Credit Sale** | A sale where payment is deferred; the customer's balance increases and is settled later. |
| **Return** | The process of returning items from a previously completed sale, restoring inventory and issuing a refund. |
| **Void** | Cancelling a sale that has not yet been fully completed (typically same-day); restores inventory. |
| **Receipt Number** | A unique, sequential identifier assigned to each completed sale. |
| **Product** | A sellable item identified by a unique SKU, with pricing and stock tracking. |
| **SKU (Stock Keeping Unit)** | A unique alphanumeric identifier for each product variant. |
| **Category** | A hierarchical grouping of products (e.g., "Electronics" → "Computers"). |
| **Supplier** | An entity that provides products to the business. |
| **Restock** | The act of increasing a product's stock quantity (e.g., receiving new inventory). |
| **Stock Adjustment** | A manual change to a product's stock quantity (e.g., for damaged goods). |
| **Stock Movement** | Any change to a product's stock quantity, logged with the actor, type, and reason. |
| **Dashboard** | A visual summary of KPIs and metrics for a specific role. |
| **Report** | A formatted collection of data, often filtered and exportable. |
| **Notification** | An in-app alert about a system event (e.g., low stock, sale completed). |
| **Business Owner** | A stakeholder who uses dashboards and reports to make decisions. |
| **Administrator** | A user with full system access — manages products, users, reports, settings. |
| **Cashier** | A user with limited access — processes sales and returns, views own data. |
| **Credit Balance** | The outstanding amount owed by a customer for credit purchases. |
| **Payment Method** | How a sale is paid: cash, card, or credit (deferred). |
| **Transaction Record** | The atomic record of a sale or return stored in the database. |
| **Audit Trail** | An immutable record of all significant actions performed in the system. |
| **Soft Delete** | Marking a record as deleted (e.g., `is_deleted = true`) rather than removing it from the database. |

---

## 3. Technical Terms

| Term | Definition |
|------|------------|
| **Clean Architecture** | A software architecture pattern that separates concerns into concentric layers (Entities, Use Cases, Interface Adapters, Frameworks). |
| **REST (Representational State Transfer)** | An architectural style for designing networked applications, using HTTP methods (GET, POST, PUT, DELETE). |
| **JWT (JSON Web Token)** | A compact, URL-safe token format for securely transmitting claims between parties. |
| **RBAC (Role-Based Access Control)** | An access control model where permissions are assigned to roles, and users are assigned to roles. |
| **ORM (Object-Relational Mapping)** | A technique that connects object-oriented code to relational databases using objects. |
| **SQLAlchemy** | A Python SQL toolkit and ORM. |
| **Pydantic** | A Python data validation and settings management library. |
| **FastAPI** | A modern, high-performance Python web framework for building APIs. |
| **React** | A JavaScript library for building user interfaces. |
| **Vite** | A modern frontend build tool. |
| **TypeScript** | A typed superset of JavaScript. |
| **Tailwind CSS** | A utility-first CSS framework. |
| **React Hook Form** | A React library for form state management. |
| **Zod** | A TypeScript-first schema validation library. |
| **TanStack Query** | A data synchronization library for React (formerly React Query). |
| **Axios** | A promise-based HTTP client. |
| **Alembic** | A database migration tool for SQLAlchemy. |
| **Swagger / OpenAPI** | A framework for designing, documenting, and consuming REST APIs. |
| **bcrypt** | A password hashing function designed to be slow (computationally expensive). |
| **Argon2** | A modern password hashing algorithm (winner of the Password Hashing Competition). |
| **Stored Procedure** | A precompiled collection of SQL statements stored in the database. |
| **View** | A saved SQL query that can be queried like a table. |
| **Trigger** | A stored procedure automatically executed by the database on certain events. |
| **Transaction** | A sequence of database operations executed as a single unit of work. |
| **ACID** | Atomicity, Consistency, Isolation, Durability — properties of reliable database transactions. |
| **SOLID** | Five design principles for object-oriented software: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion. |
| **CI/CD** | Continuous Integration / Continuous Deployment — automated pipelines for testing and releasing software. |
| **Docker** | A platform for developing, shipping, and running applications in containers. |
| **Nginx** | A web server/reverse proxy. |
| **CORS (Cross-Origin Resource Sharing)** | A mechanism that allows restricted resources on a web page to be accessed from another origin. |
| **CSP (Content-Security-Policy)** | An HTTP header that helps prevent XSS attacks. |
| **HSTS (HTTP Strict Transport Security)** | A header that forces browsers to use HTTPS. |
| **XSS (Cross-Site Scripting)** | A security vulnerability that allows injecting malicious scripts into web pages. |
| **CSRF (Cross-Site Request Forgery)** | An attack where a malicious website causes the user's browser to perform unwanted actions. |
| **SQL Injection** | A code injection technique that exploits security vulnerabilities in an application's database layer. |
| **Rate Limiting** | Restricting the number of requests a user can make in a given time period. |
| **HttpOnly Cookie** | A cookie that cannot be accessed via JavaScript, reducing XSS risk. |
| **SameSite Cookie Attribute** | A cookie attribute that controls whether the cookie is sent with cross-site requests, mitigating CSRF. |
| **Correlation ID** | A unique identifier attached to a request for tracing across services. |
| **Soft Login** | Login flow where the user must change a temporary password on first login. |
| **Paginated Response** | A response that returns a subset of results with metadata about the total count and page navigation. |
| **Idempotent** | An operation that produces the same result no matter how many times it is executed. |
| **TCL (Transaction Control Language)** | SQL commands that manage database transactions (COMMIT, ROLLBACK). |

---

## 4. Abbreviations

| Abbreviation | Meaning |
|--------------|---------|
| POS | Point of Sale |
| API | Application Programming Interface |
| JWT | JSON Web Token |
| RBAC | Role-Based Access Control |
| CRUD | Create, Read, Update, Delete |
| HTTP | HyperText Transfer Protocol |
| HTTPS | HTTP over TLS/SSL |
| SQL | Structured Query Language |
| T-SQL | Transact-SQL |
| REST | Representational State Transfer |
| UI | User Interface |
| UX | User Experience |
| KPI | Key Performance Indicator |
| TTL | Time to Live |
| SP | Stored Procedure |
| ACID | Atomicity, Consistency, Isolation, Durability |
| CI/CD | Continuous Integration / Continuous Deployment |
| ORM | Object-Relational Mapping |
| CORS | Cross-Origin Resource Sharing |
| CSP | Content-Security-Policy |
| HSTS | HTTP Strict Transport Security |
| XSS | Cross-Site Scripting |
| CSRF | Cross-Site Request Forgery |
| SAST | Static Application Security Testing |
| DAST | Dynamic Application Security Testing |
| SLO | Service Level Objective |
| SLA | Service Level Agreement |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |
| SKU | Stock Keeping Unit |
| UUID | Universally Unique Identifier |
| URI | Uniform Resource Identifier |
| URL | Uniform Resource Locator |
| SPA | Single Page Application |
| HTML | HyperText Markup Language |
| CSS | Cascading Style Sheets |
| JSON | JavaScript Object Notation |
| PDF | Portable Document Format |
| CSV | Comma-Separated Values |
| DDL | Data Definition Language |
| DML | Data Manipulation Language |
| DDL | Data Definition Language |
| TLS | Transport Layer Security |
| SSL | Secure Sockets Layer |
| CLI | Command Line Interface |
| DSN | Data Source Name |
| ORM | Object-Relational Mapper |
| UTC | Coordinated Universal Time |
| DB | Database |
| DDL | Data Definition Language |

---

## 5. References

- [SMARTPOS_PROJECT_BIBLE.md](../AI/SMARTPOS_PROJECT_BIBLE.md)
- [24_Appendices](../24_Appendices/README.md) — Future enhancements

---

## 6. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
