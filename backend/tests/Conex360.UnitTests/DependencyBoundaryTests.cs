using System.Xml.Linq;

namespace Conex360.UnitTests;

public sealed class DependencyBoundaryTests
{
    [Theory]
    [InlineData("Conex360.Domain", new string[0])]
    [InlineData("Conex360.Application", new[] { "Conex360.Domain" })]
    [InlineData("Conex360.Infrastructure", new[] { "Conex360.Application" })]
    [InlineData("Conex360.Api", new[] { "Conex360.Application", "Conex360.Infrastructure" })]
    public void ProjectDependenciesFollowTheApprovedDirection(string project, string[] allowed)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Conex360.sln")))
        {
            directory = directory.Parent;
        }

        Assert.NotNull(directory);
        var xml = XDocument.Load(Path.Combine(directory.FullName, "src", project, project + ".csproj"));
        var actual = xml.Descendants("ProjectReference")
            .Select(reference => Path.GetFileNameWithoutExtension((string)reference.Attribute("Include")!))
            .Order().ToArray();
        Assert.Equal(allowed.Order(), actual);
        if (project == "Conex360.Domain")
        {
            Assert.Empty(xml.Descendants("PackageReference"));
        }
    }
}
