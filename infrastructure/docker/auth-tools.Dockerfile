FROM mcr.microsoft.com/dotnet/sdk:10.0.404@sha256:8c6edfb26c85153f236d26efebd9ad349aec403583f343f201ee67838b23658d
WORKDIR /source
COPY global.json ./
COPY backend/ backend/
COPY database/migrations/ database/migrations/
RUN dotnet restore backend/Conex360.sln --locked-mode && dotnet build backend/Conex360.sln -c Release --no-restore
ENTRYPOINT ["dotnet"]
