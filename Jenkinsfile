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

        B2_ENDPOINT = 'https://s3.eu-central-003.backblazeb2.com'
        AWS_DEFAULT_REGION = 'eu-central-003'
        ISO_BUCKET = 'dist-sayagit-fedora-iso'

        // Must match the <source path="..."/> in
        // repositories/kernel-sp12in.xml.
        KERNEL_SURFACE_REPO_URL = 'https://rpm.sayag.it/kernel-sp12in/fedora/45/aarch64'

        // awscli2 sends CRC32 checksums by default, which B2 rejects. Ask for
        // them only where the S3 API requires them.
        AWS_REQUEST_CHECKSUM_CALCULATION = 'when_required'
        AWS_RESPONSE_CHECKSUM_VALIDATION = 'when_required'
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
                            // The kernel-surface RPM is a build input, not
                            // something this repository can produce: the image
                            // installs kernel-surface by name and <ignore>s
                            // Fedora's kernel packages. Its pipeline publishes
                            // it to rpm.sayag.it, which repositories/kernel-sp12in.xml
                            // points at directly, so there is nothing to stage
                            // here. Fail now rather than several minutes into
                            // kiwi on an unresolvable package name.
                            sh '''
                                set -eux

                                dnf --assumeyes install curl

                                repomd="${KERNEL_SURFACE_REPO_URL}/repodata/repomd.xml"
                                if ! curl -fsS --retry 3 -o /dev/null "${repomd}"; then
                                    echo "No kernel-surface repository at ${repomd}." >&2
                                    echo "Run the kernel-surface pipeline for Fedora ${IMAGE_VERSION} first." >&2
                                    exit 1
                                fi
                            '''

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
                    withCredentials([usernamePassword(
                        credentialsId: 'backblaze-b2-dist-iso',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                            set -eux

                            cd "${OUTPUT_DIR}-build"
                            src="Fedora.aarch64-${IMAGE_VERSION}.iso"
                            moddate=$(date -r "${src}" -u +"%Y%m%d-%H%M%S")
                            dst="Fedora.Surface-Pro-12in.${IMAGE_PROFILE}.${IMAGE_VERSION}.${moddate}.aarch64.iso"
                            mv "${src}" "${dst}"
                            ls -lh

                            /s5cmd --endpoint-url "${B2_ENDPOINT}" cp \\
                                "${dst}" \\
                                "s3://${ISO_BUCKET}/fedora/${IMAGE_VERSION}/aarch64/${dst}"
                        '''
                    }
                }
            }
        }
    }
}
