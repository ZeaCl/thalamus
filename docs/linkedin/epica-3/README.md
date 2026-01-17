# Épica 3: Application Layer - Agent Tokens

**Periodo:** Enero 2026
**Estado:** ✅ Completado (Core use cases)

---

## 🎯 Objetivo de la Épica

Implementar la capa de aplicación de Thalamus con casos de uso para:
- Generación de agent tokens
- Validación de tokens
- Revocación de tokens

**Entregables principales:**
- ✅ `GenerateAgentToken` use case
- ✅ `RevokeAgentToken` use case
- ✅ DTOs (AgentTokenRequest, AgentTokenResponse)
- ✅ 38 tests con cobertura completa
- ✅ 3 security fixes críticos

---

## 📝 Contenido de LinkedIn Disponible

### 1. Security Fixes Series

#### Post #1: "3 Critical Security Holes We Found (and Fixed)"

**Tema:** Vulnerabilidades de seguridad encontradas en code review

**Problemas cubiertos:**
1. **Child TTL Validation** - Tokens hijos viviendo más que padres
2. **Scope Narrowing** - Falta de validación de scopes en delegation chains
3. **Input Sanitization** - XSS y log injection en campos de texto

**Archivos:**
- `security-fixes-agent-tokens.md` - Versión larga (2,500 palabras)
- `security-fixes-short.md` - Versión corta (800 palabras)
- `security-fixes-carousel.md` - 10 slides para carousel
- `CONTENT_GUIDE.md` - Guía completa de publicación

**Estado:** ✅ Listo para publicar
**Formato recomendado:** Carousel (máximo engagement)
**Mejor momento:** Martes o Miércoles, 8 AM PST

---

## 🔮 Contenido Futuro (Ideas)

### Post #2: "Delegation Chains in AI Agent Auth" (Próximo)

**Tema:** Cómo funciona la delegación jerárquica de autorización

**Puntos clave:**
- Parent → Child → Grandchild relationships
- Scope narrowing automático
- TTL inheritance
- Use case: Workflow orchestration con subagentes

**Formato sugerido:** Post corto con diagrama visual
**Fecha estimada:** +1 semana del post anterior

---

### Post #3: "Testing Strategy for Use Cases with Dependency Injection"

**Tema:** Cómo testeamos use cases sin tocar la base de datos

**Puntos clave:**
- Mox para mocking de repositories
- Pure unit tests (0 DB hits)
- 38 tests en <1 segundo
- Pattern reusable para otros use cases

**Formato sugerido:** Artículo largo técnico
**Fecha estimada:** +2 semanas

---

### Post #4: "DTOs vs Domain Entities: When to Use Each"

**Tema:** Separación de concerns en Clean Architecture

**Puntos clave:**
- DTOs para request/response (web layer)
- Entities para business logic (domain layer)
- Por qué no usar entities directamente en controllers
- Validación en múltiples capas

**Formato sugerido:** Post corto educativo
**Fecha estimada:** +3 semanas

---

## 📊 Métricas de Éxito

### Objetivos para Épica 3 Content

**Engagement:**
- [ ] >5,000 impresiones en post principal
- [ ] >250 interacciones (likes + comments + shares)
- [ ] >20 comentarios con discusión técnica

**Community:**
- [ ] >10 connection requests de roles relevantes
- [ ] 3+ conversaciones profundas en comments
- [ ] Mencionado en 1+ newsletter/blog externo

**Brand:**
- [ ] "Thalamus" buscado en Google +50%
- [ ] GitHub stars en repo +20
- [ ] Traffic a docs desde LinkedIn +30%

---

## 🎨 Assets Creados

### Code Snippets
- ✅ Child TTL validation (Elixir)
- ✅ Scope narrowing validation (Elixir)
- ✅ Input sanitizer module (Elixir)

### Visuales Necesarios (Pendientes)
- [ ] Delegation chain diagram (parent → child → grandchild)
- [ ] Scope narrowing flowchart
- [ ] TTL inheritance timeline
- [ ] Clean Architecture layer diagram

**Herramienta recomendada:** Excalidraw, Mermaid, o Figma

---

## 🗂️ Estructura de Archivos

```
docs/linkedin/epica-3/
├── README.md                           # Este archivo
├── CONTENT_GUIDE.md                    # Guía de publicación
├── security-fixes-agent-tokens.md      # Post largo
├── security-fixes-short.md             # Post corto
├── security-fixes-carousel.md          # Carousel
└── (futuros posts aquí)
```

---

## 🔗 Referencias

**Commits relacionados:**
- `35809a4` - Security fixes (TTL, scopes, sanitization)
- `44e71d0` - LinkedIn content creation

**PR relacionados:**
- PR #1 - Epic 3: Application Layer implementation

**Archivos de código:**
- `lib/thalamus/application/use_cases/generate_agent_token.ex`
- `lib/thalamus/utils/input_sanitizer.ex`
- `test/thalamus/application/use_cases/generate_agent_token_test.exs`

---

## 💡 Lecciones Aprendidas

### Técnicas
1. **Code review encontró 3 security holes** que automated tests no detectaron
2. **Scope validation debe ser en múltiples niveles** (client, parent, organization)
3. **TTL inheritance es crítico** en delegation chains
4. **Input sanitization debe ser default**, no optional

### De Proceso
1. **Inline comments en PR** son más útiles que general feedback
2. **Documentar problemas MIENTRAS se arreglan** genera mejor content
3. **Build in public** genera engagement auténtico

### Para Próximas Épicas
1. Security review ANTES de merge, no después
2. Generar LinkedIn content como parte del workflow
3. Crear assets visuales durante implementation, no después

---

## 📝 Template para Futuros Posts

Cuando agregues nuevo contenido a esta épica:

1. **Crear archivo markdown** con el tema
2. **Seguir estructura:**
   - Hook (problema)
   - Context (por qué importa)
   - Solution (código + explicación)
   - Impact (métricas, beneficios)
   - CTA (preguntas, discusión)
3. **Actualizar este README** con el nuevo post
4. **Agregar a calendario** en README principal

---

**Next:** Publicar post de security fixes y trackear métricas 📈
