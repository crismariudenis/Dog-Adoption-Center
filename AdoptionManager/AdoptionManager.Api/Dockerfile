FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*
USER $APP_UID
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["AdoptionManager.Api/AdoptionManager.Api.csproj", "AdoptionManager.Api/"]
COPY ["AdoptionManager.Application/AdoptionManager.Application.csproj", "AdoptionManager.Application/"]
COPY ["AdoptionManager.Domain/AdoptionManager.Domain.csproj", "AdoptionManager.Domain/"]
COPY ["AdoptionManager.Infrastructure/AdoptionManager.Infrastructure.csproj", "AdoptionManager.Infrastructure/"]
RUN dotnet restore "AdoptionManager.Api/AdoptionManager.Api.csproj"
COPY . .
WORKDIR "/src/AdoptionManager.Api"
RUN dotnet build "AdoptionManager.Api.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "AdoptionManager.Api.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "AdoptionManager.Api.dll"]
