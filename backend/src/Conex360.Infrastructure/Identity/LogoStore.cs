using Conex360.Application.Identity;
using SkiaSharp;

namespace Conex360.Infrastructure.Identity;

public sealed class StorageSettings
{
    public string LogoDirectory { get; set; } = "";
    public string KeyDirectory { get; set; } = "";
    public string CertificateFile { get; set; } = "";
    public string CertificatePasswordFile { get; set; } = "";
}

public sealed class LogoStore(StorageSettings settings) : ILogoStore
{
    public const int MaximumBytes = 2 * 1024 * 1024;
    public static byte[] Sanitize(byte[] input)
    {
        if (input.Length == 0 || input.Length > MaximumBytes) throw Invalid();
        using var data = SKData.CreateCopy(input);
        using var codec = SKCodec.Create(data);
        if (codec is null || codec.EncodedFormat is not (SKEncodedImageFormat.Png or SKEncodedImageFormat.Jpeg)
            || codec.Info.Width is < 1 or > 2048 || codec.Info.Height is < 1 or > 2048
            || codec.FrameCount > 1) throw Invalid();
        using var bitmap = new SKBitmap(new SKImageInfo(codec.Info.Width, codec.Info.Height, SKColorType.Rgba8888, SKAlphaType.Premul));
        if (codec.GetPixels(bitmap.Info, bitmap.GetPixels()) != SKCodecResult.Success) throw Invalid();
        using var image = SKImage.FromBitmap(bitmap);
        using var output = image.Encode(SKEncodedImageFormat.Png, 100);
        return output.ToArray();
    }
    private static AppFailure Invalid() => new(400, "INVALID_LOGO", "Upload a complete PNG or JPEG up to 2 MiB and 2048 × 2048 pixels.");
    private string PathFor(ulong tenant, ulong company, string key)
    {
        if (string.IsNullOrWhiteSpace(settings.LogoDirectory)) throw new AppFailure(503, "STORAGE_UNAVAILABLE", "Logo storage is unavailable.");
        if (key.Length != 36 || !key.EndsWith(".png", StringComparison.Ordinal) || !System.Guid.TryParseExact(key[..32], "N", out _)) throw Invalid();
        return Path.Combine(Path.GetFullPath(settings.LogoDirectory), tenant.ToString(System.Globalization.CultureInfo.InvariantCulture), company.ToString(System.Globalization.CultureInfo.InvariantCulture), key);
    }
    public async Task<string> SaveAsync(ulong tenantId, ulong companyId, Stream input, CancellationToken ct)
    {
        using var buffer = new MemoryStream();
        var block = new byte[8192];
        int count;
        while ((count = await input.ReadAsync(block, ct)) > 0)
        {
            if (buffer.Length + count > MaximumBytes) throw Invalid();
            await buffer.WriteAsync(block.AsMemory(0, count), ct);
        }
        var bytes = Sanitize(buffer.ToArray());
        var key = System.Guid.NewGuid().ToString("N") + ".png";
        var path = PathFor(tenantId, companyId, key);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await using var file = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 8192, true);
        await file.WriteAsync(bytes, ct);
        return key;
    }
    public async Task<byte[]?> ReadAsync(ulong tenantId, ulong companyId, string key, CancellationToken ct)
    {
        var path = PathFor(tenantId, companyId, key);
        return File.Exists(path) ? await File.ReadAllBytesAsync(path, ct) : null;
    }
    public Task RemoveNewAsync(ulong tenantId, ulong companyId, string key, CancellationToken ct)
    {
        File.Delete(PathFor(tenantId, companyId, key));
        return Task.CompletedTask;
    }
}
