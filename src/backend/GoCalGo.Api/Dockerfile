# ---------- restore ----------
FROM mcr.microsoft.com/dotnet/sdk:11.0-alpine AS restore
WORKDIR /src

COPY Directory.Build.props .
COPY GoCalGo.Api/GoCalGo.Api.csproj GoCalGo.Api/
RUN dotnet restore GoCalGo.Api/GoCalGo.Api.csproj --runtime linux-musl-x64

# ---------- build / publish ----------
FROM restore AS publish

COPY GoCalGo.Api/ GoCalGo.Api/
COPY GoCalGo.Contracts/ GoCalGo.Contracts/
RUN dotnet publish GoCalGo.Api/GoCalGo.Api.csproj \
    -c Release \
    -o /app/publish \
    --runtime linux-musl-x64 \
    --self-contained false \
    --no-restore

# ---------- runtime ----------
FROM mcr.microsoft.com/dotnet/aspnet:11.0-alpine AS runtime

# Harden: non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=publish /app/publish .

# Drop privileges
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "GoCalGo.Api.dll"]
