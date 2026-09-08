provider "helm" {
}

resource "helm_release" "fixture" {
}

# ownership leak: helm    install
# ownership leak: helm    upgrade
