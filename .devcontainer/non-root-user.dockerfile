ARG BASE_IMAGE
FROM ${BASE_IMAGE}

LABEL maintainer="Sylvia Schmitt"

ARG USER_NAME=$USER
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV HOMEDIR=/home/${USER_NAME}

RUN echo "echo test"
RUN echo "home dir: $HOMEDIR"
RUN echo "user name: $USER_NAME"
RUN echo "user id: $USER_UID"
RUN echo "group id: $USER_GID"

# Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
# Section https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_creating-a-nonroot-user

# Create the user
RUN groupadd --gid $USER_GID $USER_NAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USER_NAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.    
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USER_NAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME \
    && chmod 0440 /etc/sudoers.d/$USER_NAME
# anything else goes here

# [Optional] Set the default user. Omit if you want to keep the default as root.
USER $USER_NAME