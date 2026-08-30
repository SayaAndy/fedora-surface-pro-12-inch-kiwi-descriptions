pipeline {
    agent none

    options {
        timestamps()
    }

    environment {
        KIWI_FILE = 'Fedora.kiwi'
        IMAGE_TYPE = 'iso'
        IMAGE_PROFILE = 'Workstation-Live'
        IMAGE_VERSION = '45'
        OUTPUT_DIR = 'outdir'
    }

    stages {
        stage('Build Fedora Workstation Live ISO (ARM64)') {
            agent {
                kubernetes {
                    defaultContainer 'kiwi'
                    yaml """
apiVersion: v1
kind: Pod
metadata:
  namespace: jenkins
spec:
  nodeSelector:
    kubernetes.io/arch: arm64
  containers:
    - name: kiwi
      image: fedora:44
      imagePullPolicy: Always
      command: [ 'sleep' ]
      args: [ 'infinity' ]
      tty: true
      securityContext:
        privileged: true
      resources:
        requests:
          cpu: "2"
          memory: 4Gi
          ephemeral-storage: 20Gi
        limits:
          memory: 12Gi
          ephemeral-storage: 50Gi
"""
                }
            }
            steps {
                checkout scm
                container('kiwi') {
                    script {
                        try {
                            sh '''
                                dnf --assumeyes install git kiwi kiwi-systemdeps distribution-gpg-keys
                                git config --global --add safe.directory .
                                git submodule update --init --recursive

                                ./kiwi-build \\
                                    --kiwi-file="${KIWI_FILE}" \\
                                    --image-type="${IMAGE_TYPE}" \\
                                    --image-profile="${IMAGE_PROFILE}" \\
                                    --output-dir "${OUTPUT_DIR}"

                                ls -lh "${OUTPUT_DIR}-build"
                            '''
                        } catch (Exception e) {
                            echo "Caught exception: ${e.getMessage()}"
                            currentBuild.result = 'FAILURE'
                            throw e
                        }
                    }
                    stash name: "fedora-workstation-live-iso-stash", includes: "${OUTPUT_DIR}-build/Fedora.aarch64-${IMAGE_VERSION}.iso"
                }
            }
        }

        stage('Push Fedora Workstation Live ISO (ARM64)') {
            agent {
                kubernetes {
                    defaultContainer 's5cmd'
                    yaml """
apiVersion: v1
kind: Pod
metadata:
  namespace: jenkins
spec:
  containers:
    - name: s5cmd
      image: peakcom/s5cmd:v2.3.0
      imagePullPolicy: IfNotPresent
      command: [ 'sleep' ]
      args: [ 'infinity' ]
      tty: true
      resources:
        requests:
          cpu: "0.5"
          memory: 4Gi
"""
                }
            }
            steps {
                container('s5cmd') {
                    unstash "fedora-workstation-live-iso-stash"
                    sh '''
                        cd ${OUTPUT_DIR}-build
                        moddate=$(date -r Fedora.aarch64-${IMAGE_VERSION}.iso -u +"%Y%m%d-%H%M%S")
                        mv Fedora.aarch64-${IMAGE_VERSION}.iso "Fedora.Surface-Pro-12in.${IMAGE_PROFILE}.${IMAGE_VERSION}.${moddate}.aarch64.iso"
                        ls -lh
                    '''
                }
            }
        }
    }
}
