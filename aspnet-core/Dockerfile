# Use build image
FROM mcr.microsoft.com/dotnet/core/sdk AS build-env

# Set working directory
WORKDIR /app

# copy everything and build
COPY . ./

# Publish to 'out' folder
RUN dotnet publish -c Release -o out

# build runtime image
FROM mcr.microsoft.com/dotnet/core/aspnet

# Set working directory
WORKDIR /app

# Copy build artifacts from previous stage
COPY --from=build-env /app/out .

# Ensure that the dll file name matches the tag specified in the 'docker build' command
ENTRYPOINT ["dotnet", "aspnet-core.dll"]