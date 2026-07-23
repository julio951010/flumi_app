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
subprojects {
    project.evaluationDependsOn(":app")
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
        if (androidExtension.compileSdkVersion == "android-30") {
            androidExtension.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
