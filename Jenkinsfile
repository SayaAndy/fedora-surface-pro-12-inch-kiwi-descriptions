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
        RPM_BUCKET = 'dist-sayagit-fedora-rpm'
        ISO_BUCKET = 'dist-sayagit-fedora-iso'

        // awscli2 sends CRC32 checksums by default, which B2 rejects. Ask for
        // them only where the S3 API requires them.
        AWS_REQUEST_CHECKSUM_CALCULATION = 'when_required'
        AWS_RESPONSE_CHECKSUM_VALIDATION = 'when_required'

        // Must match the <source path="dir://..."/> in
        // repositories/kernel-surface.xml.
        KERNEL_SURFACE_REPO = '/var/lib/kernel-surface-repo'
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
                            // Fedora's kernel packages, so it has to be in the
                            // local repository before kiwi starts. The buckets
                            // stay private, so it is pulled with credentials
                            // rather than fetched over a public URL.
                            withCredentials([usernamePassword(
                                credentialsId: 'backblaze-b2-dist-rpm',
                                usernameVariable: 'AWS_ACCESS_KEY_ID',
                                passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                                sh '''
                                    set -eux

                                    dnf --assumeyes install awscli2 createrepo_c

                                    mkdir -p "${KERNEL_SURFACE_REPO}"
                                    aws s3 sync --endpoint-url "${B2_ENDPOINT}" \\
                                        "s3://${RPM_BUCKET}/fedora/${IMAGE_VERSION}/aarch64/" \\
                                        "${KERNEL_SURFACE_REPO}/" \\
                                        --exclude '*' --include 'kernel-surface-*.rpm'

                                    # Say so here rather than letting kiwi fail
                                    # several minutes later on an unresolvable
                                    # package name.
                                    if ! ls "${KERNEL_SURFACE_REPO}"/kernel-surface-*.rpm; then
                                        echo "No kernel-surface RPM in ${RPM_BUCKET} for Fedora ${IMAGE_VERSION}." >&2
                                        echo "Run the kernel-surface pipeline first." >&2
                                        exit 1
                                    fi

                                    createrepo_c "${KERNEL_SURFACE_REPO}"
                                '''
                            }

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

                            s5cmd --endpoint-url "${B2_ENDPOINT}" cp \\
                                "${dst}" \\
                                "s3://${ISO_BUCKET}/fedora/${IMAGE_VERSION}/aarch64/${dst}"
                        '''
                    }
                }
            }
        }
    }
}
