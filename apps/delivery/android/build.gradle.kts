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
    project.configurations.all {
        resolutionStrategy.force(
            "androidx.test:runner:1.3.0",
            "androidx.test:rules:1.2.0",
            "androidx.test:monitor:1.3.0",
            "androidx.test.espresso:espresso-core:3.3.0",
            "androidx.test.espresso:espresso-idling-resource:3.3.0",
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
