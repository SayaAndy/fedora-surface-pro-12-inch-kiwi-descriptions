pipeline {
    agent none

    options {
        timestamps()
    }

    environment {
        KIWI_FILE = 'Fedora.kiwi'
        IMAGE_TYPE = 'iso'
        IMAGE_PROFILE = 'Workstation-Live'
        OUTPUT_DIR = 'outdir'
    }

    stages {
        stage('Build Fedora Workstation (ARM64)') {
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
                }
            }
        }
    }
}
