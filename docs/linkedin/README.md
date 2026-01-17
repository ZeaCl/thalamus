# LinkedIn Content - Thalamus

Este directorio contiene contenido listo para publicar en LinkedIn sobre el desarrollo de Thalamus, organizado por épica.

---

## 📁 Estructura por Épicas

Cada épica tiene su propio subdirectorio con contenido específico sobre los logros, aprendizajes y desafíos de esa fase del proyecto.

---

### [Épica 3: Application Layer - Agent Tokens](/docs/linkedin/epica-3/)

**Fecha:** Enero 2026
**Estado:** ✅ Completado
**Focus:** Implementación del caso de uso GenerateAgentToken con validaciones de seguridad

**Contenido disponible:**
- 🔐 Security Fixes: 3 vulnerabilidades críticas encontradas y corregidas
  - Child TTL validation
  - Scope narrowing en delegation chains
  - Input sanitization

**Formatos:**
- Artículo largo (2,500 palabras)
- Post corto (800 palabras)
- Carousel de 10 slides

**Link:** [Ver contenido de Épica 3](./epica-3/CONTENT_GUIDE.md)

---

## 📋 Épicas Futuras

### Épica 4: Infrastructure Layer (Próximamente)
**Focus:** Repositorios, persistencia, event sourcing

**Temas potenciales:**
- PostgreSQL schema design for agent tokens
- Event sourcing para audit trails
- Repository pattern implementation

---

### Épica 5: Integration with Cerebelum (Próximamente)
**Focus:** Validación de autorización para workflow steps

**Temas potenciales:**
- Thalamus.API public interface
- ValidateStepAuthorization use case
- HTTP vs Direct integration patterns
- Umbrella project architecture

---

## 🎯 Estrategia de Contenido

### Objetivos
1. **Thought Leadership:** Posicionar a ZEA/Thalamus como expertos en auth para AI agents
2. **Community Building:** Atraer developers interesados en agentic systems
3. **Recruitment:** Mostrar nivel técnico del equipo
4. **Product Awareness:** Dar a conocer Thalamus como OAuth2 para agents

---

### Formatos que Funcionan

**Por Engagement:**
1. 🥇 **Carousel** (3-5x engagement de posts normales)
2. 🥈 **Post corto con code snippets** (fácil de consumir)
3. 🥉 **Artículo largo** (SEO, referenciable)

**Por Objetivo:**
- **Viral reach:** Carousel con visual atractivo
- **Technical depth:** Artículo largo
- **Quick wins:** Post corto en feed

---

### Calendario de Publicación

| Épica | Tema | Formato | Fecha Sugerida | Estado |
|-------|------|---------|----------------|--------|
| 3 | Security Fixes | Carousel | Martes 8 AM PST | ✅ Listo |
| 3 | Lessons Learned | Post corto | +1 semana | 📝 Draft |
| 4 | Event Sourcing | Artículo | TBD | ⏳ Pendiente |
| 5 | Cerebelum Integration | Carousel | TBD | ⏳ Pendiente |

---

## 📊 Métricas Objetivo

### Por Post
- **Impresiones:** 5,000-10,000
- **Engagement rate:** >5%
- **Comments:** >20 con discusión técnica
- **Profile views:** +20% spike post-publicación

### Acumulativo (6 meses)
- **Followers:** +500 technical followers
- **Network:** +100 connections relevantes (CTOs, Engineering Managers)
- **Mentions:** Thalamus mencionado en 5+ artículos/posts externos

---

## 🎨 Brand Guidelines

### Tono
- **Technical pero accesible:** Usa código real, pero explica el "why"
- **Humble confidence:** Comparte problemas Y soluciones
- **Community-first:** Invita a discusión, no solo broadcasting

### Visual Identity
- **Colors:** Dark blue (#1a1f36) + Electric blue (#00d4ff)
- **Code snippets:** Syntax highlighted, max 10 líneas
- **Emojis:** Úsalos para structure, no como filler

### Hashtags Core
- #AIEngineering
- #Security
- #OAuth2
- #AgenticAI
- #Elixir
- #ZEA

---

## 🔄 Reutilización de Contenido

Cada pieza de LinkedIn puede convertirse en:

1. **Twitter/X thread** (versión ultra-corta, 5-10 tweets)
2. **Blog post** en zea.io (versión expandida con más ejemplos)
3. **YouTube video** (screen recording + explicación)
4. **Dev.to article** (para developer community)
5. **Newsletter** (para subscribers)
6. **Conference talk** (usar como base para CFPs)

---

## 📝 Template para Nuevas Épicas

Cuando empieces una nueva épica, crea:

```
docs/linkedin/epica-[número]/
├── CONTENT_GUIDE.md         # Guía de uso y publicación
├── [tema]-long.md            # Versión artículo largo
├── [tema]-short.md           # Versión post corto
├── [tema]-carousel.md        # Versión carousel
└── assets/                   # Imágenes, gráficos (si aplica)
    └── carousel-slides/
```

**Checklist:**
- [ ] Identificar 1-3 temas principales de la épica
- [ ] Escribir versión larga (context + technical depth)
- [ ] Crear versión corta (problema + solución + CTA)
- [ ] Diseñar carousel (10 slides, visual + código)
- [ ] Definir hashtags específicos
- [ ] Agendar fecha de publicación
- [ ] Preparar respuestas a comentarios comunes

---

## 🤝 Colaboración

Si otros miembros del equipo van a publicar:

1. **Coordinar timing:** No publicar 2 posts el mismo día
2. **Cross-promote:** Comentar y compartir posts de otros
3. **Tag apropiadamente:** @ZEA_Platform en posts relevantes
4. **Mantener consistencia:** Seguir brand guidelines

---

## 📚 Recursos Útiles

- **Canva:** Para diseñar carousels (gratis)
- **Carbon.now.sh:** Para screenshots de código bonitos
- **LinkedIn Article Editor:** Para posts largos con formato
- **Buffer/Hootsuite:** Para agendar posts (opcional)

---

**¿Preguntas?** Revisa el CONTENT_GUIDE.md de cada épica para guías específicas.

**¡Let's build in public! 🚀**
