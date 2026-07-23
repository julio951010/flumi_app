# Flumi
**Déjate llevar por la corriente**

App de citas offline-first para el mercado cubano. Flutter + Isar (local) + Supabase (nube).

Ver `ARCHITECTURE.md` para el detalle completo de decisiones de arquitectura.

## Estado actual

Esto es un **andamiaje de Fase 1**: modelos de datos, esquema SQL y servicios de
sincronización. Todavía NO incluye las carpetas nativas de Android/iOS ni los
adaptadores generados de Isar — hay que generarlos localmente (ver abajo).

## Setup en tu máquina

1. **Genera la estructura nativa de Flutter encima de este repo** (Android/iOS/etc.):
   ```bash
   flutter create .
   ```
   Esto respeta los archivos que ya existen (`lib/`, `pubspec.yaml`) y solo
   agrega lo que falta (carpetas `android/`, `ios/`, `test/`, etc.).

2. **Instala dependencias**:
   ```bash
   flutter pub get
   ```
   Nota: `isar_flutter_libs` descarga binarios nativos desde GitHub Releases
   en este paso. Si usas proxy (Psiphon3 u otro), asegúrate de que cubra
   `objects.githubusercontent.com`.

3. **Genera los adaptadores de Isar** (los archivos `*.g.dart` que los
   modelos importan con `part` no están en el repo — están en `.gitignore`
   a propósito, se regeneran siempre):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Configura Supabase**:
   - Crea un proyecto en [supabase.com](https://supabase.com) (plan gratuito).
   - Ve a *SQL Editor* → pega el contenido de `supabase/schema.sql` → *Run*.
   - Copia tu `Project URL` y `anon public key` desde *Settings → API*.
   - Pégalos en `lib/main.dart` (constantes `supabaseUrl` y `supabaseAnonKey`)
     — o mejor, pásalos por `--dart-define` para no dejarlos en el código:
     ```bash
     flutter run --dart-define=SUPABASE_URL=https://gzozmebdrsdcupgvxuiv.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6b3ptZWJkcnNkY3VwZ3Z4dWl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NDEwMjAsImV4cCI6MjEwMDMxNzAyMH0.WOVstBsW57idlX0LiceKIYcJOvCVTf5wdGiib20Y5ZY
     ```

5. **Corre la app**:
   ```bash
   flutter run
   ```

## Subir a GitHub

```bash
git init
git add .
git commit -m "Fase 1: arquitectura, modelos Isar, esquema Supabase, servicios de sync"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/flumi.git
git push -u origin main
```

⚠️ Antes del primer commit, revisa que `lib/main.dart` no tenga tus claves
reales de Supabase si vas a subir el repo como público — usa `--dart-define`
o un archivo `.env` (ya está en `.gitignore`).

## Próximos pasos (Fase 2)

Ver sección 6 de `ARCHITECTURE.md` — hay tres decisiones de producto pendientes
antes de construir las pantallas de swipe, chat y perfil.
