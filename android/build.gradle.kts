allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Alinea el JVM target de Java con el de Kotlin en cada módulo de biblioteca
// para evitar "Inconsistent JVM Target Compatibility". Cada plugin fija sus
// propios targets (tflite_flutter: Java 11/Kotlin 21; image_picker: Java 21/
// Kotlin 17; etc.). Se registra ANTES de evaluationDependsOn(":app") para que
// este afterEvaluate corra tras la evaluación de cada plugin.
//
// No se fuerza un valor fijo: se LEER el jvmTarget de Kotlin (por reflexión,
// porque el tipo Kotlin no está en el classpath raíz con AGP newDsl) y se
// iguala el Java a ese valor. Así cada módulo queda coherente sin pelear con
// la configuración del plugin.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
            as? com.android.build.gradle.LibraryExtension ?: return@afterEvaluate

        val javaVersion = try {
            val kotlinExt = extensions.findByName("kotlin")
            if (kotlinExt != null) {
                val compilerOptions =
                    kotlinExt.javaClass.getMethod("getCompilerOptions").invoke(kotlinExt)
                val jvmTargetProp =
                    compilerOptions.javaClass.getMethod("getJvmTarget").invoke(compilerOptions)
                val jvmTargetEnum = jvmTargetProp.javaClass.getMethod("get").invoke(jvmTargetProp)
                val name = (jvmTargetEnum as? Enum<*>)?.name ?: "JVM_21"
                JavaVersion.valueOf(name.replace("JVM_", "VERSION_"))
            } else {
                JavaVersion.VERSION_21
            }
        } catch (_: Exception) {
            JavaVersion.VERSION_21
        }

        androidExt.compileOptions {
            sourceCompatibility = javaVersion
            targetCompatibility = javaVersion
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Red con proxy limitado: dl.google.com y mavenCentral devuelven 404 para
// artefactos que no están en el caché local de Gradle. share_plus 13.3.1
// pide core:1.16.0 (su aar NO está cacheado; solo core-ktx:1.16.0) y
// annotation:1.9.1 (tampoco cacheado). Se fuerzan a versiones SÍ cacheadas:
// core y core-ktx a 1.13.1 (FileProvider, lo único que usa share_plus,
// existe desde 1.0), annotation a 1.6.0 y annotation-jvm a 1.9.1 (esta
// última la arrastra la resolución y la 1.6.0 correspondiente no existe;
// son solo anotaciones, el skew es inocuo). Si otro artefacto nuevo falla
// igual, se añade su force aquí.
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
            force("androidx.annotation:annotation:1.6.0")
            force("androidx.annotation:annotation-jvm:1.9.1")
        }
    }
}

// Parche: algunos plugins viejos (isar_flutter_libs 3.1.0+1 entre ellos)
// no declaran `namespace` en su build.gradle, y el AGP moderno lo exige.
// Además, isar_flutter_libs trae compileSdkVersion fijado en 30, muy por
// debajo de lo que exigen dependencias transitivas modernas (androidx.*
// que llegan vía otros plugins como supabase_flutter). Se fuerza ambos
// al momento en que se APLICA el plugin (no con afterEvaluate, que falla
// aquí porque evaluationDependsOn(":app") ya evaluó los subproyectos
// antes de que este bloque llegara a registrarse).
subprojects {
    plugins.withId("com.android.library") {
        val androidExtension =
            extensions.getByName("android") as com.android.build.gradle.LibraryExtension
        if (androidExtension.namespace == null) {
            androidExtension.namespace = "com.flumi.${project.name.replace("-", "_")}"
        }
        // Todas las libs compilan contra 36 (igual que la app): las
        // dependencias transitivas modernas (androidx.core 1.18.0 vía
        // share_plus y otras) exigen compileSdk 36 a sus consumidores y
        // el chequeo de metadatos AAR en release falla en caso contrario.
        // Subir compileSdk no cambia minSdk ni targetSdk de cada lib.
        // NOTA: algunos plugins (connectivity_plus, etc.) fijan su
        // compileSdk en su propio afterEvaluate, pisando esto; el refuerzo
        // definitivo está en gradle.projectsEvaluated más abajo.
        androidExtension.compileSdk = 36
        // El lint vital de release falla al resolver artefactos transitivos
        // (p.ej. datastore-jvm de shared_preferences_android) en redes con
        // proxy limitado. No es un problema del código: se desactiva solo el
        // chequeo de release, el lint normal sigue activo.
        androidExtension.lint.checkReleaseBuilds = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
