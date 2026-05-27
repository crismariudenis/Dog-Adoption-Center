using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using AdoptionManager.Api.Contracts;
using Microsoft.AspNetCore.Http;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Processing;

namespace AdoptionManager.Api.Services;

public class SimpleDocumentAnalysisService : ISimpleDocumentAnalysisService
{
    private static readonly string[] NameStopWords =
    {
        "ID", "CARD", "PASSPORT", "IDENTITY", "REPUBLIC", "NATIONAL", "ISSUED", "VALID", "ADDRESS"
    };

    private static readonly string[] IdentityKeywords =
    {
        "PASSPORT", "IDENTITY", "ID", "CARD", "NATIONALITY", "DATE OF BIRTH", "BIRTH", "SURNAME", "GIVEN NAMES", "EXPIRY", "ISSUING"
    };

    public async Task<DocumentAnalysisResponse> AnalyzeIdAsync(IFormFile idDocument, string? expectedFullName, CancellationToken cancellationToken)
    {
        var warnings = new List<string>();

        var isImageDocument = idDocument.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase);
        var hasImageData = await TryDetectImageDataAsync(idDocument, cancellationToken);
        if (!hasImageData)
        {
            warnings.Add("Could not detect image metadata from the uploaded file.");
        }

        var extractedText = await TryExtractTextWithTesseractAsync(idDocument, cancellationToken);
        if (string.IsNullOrWhiteSpace(extractedText))
        {
            warnings.Add("No OCR text extracted. Ensure Tesseract is installed and the document is readable.");
            extractedText = string.Empty;
        }

        var extractedName = TryExtractNameCandidate(extractedText);
        if (string.IsNullOrWhiteSpace(extractedName))
        {
            warnings.Add("Could not infer a clear name from OCR text.");
        }

        var hasFaceLikeRegion = await TryDetectFaceLikeRegionAsync(idDocument, cancellationToken);
        if (!hasFaceLikeRegion)
        {
            warnings.Add("Could not detect a face-like region in the ID image.");
        }

        return new DocumentAnalysisResponse
        {
            IsImageDocument = isImageDocument,
            HasImageData = hasImageData,
            ExtractedName = extractedName,
            NameMatchesExpected = true,
            HasFaceLikeRegion = hasFaceLikeRegion,
            ExtractedTextPreview = BuildPreview(extractedText),
            Warnings = warnings
        };
    }

    public async Task<DocumentExtractionResponse> AnalyzeDocumentsAsync(
        IFormFile idDocument,
        IFormFile bankStatementDocument,
        string? expectedFullName,
        CancellationToken cancellationToken)
    {
        var warnings = new List<string>();

        var idText = await TryExtractTextWithTesseractAsync(idDocument, cancellationToken);
        var idName = TryExtractNameCandidate(idText);
        var idPreviewBase64 = await TryBuildPreviewBase64Async(idDocument, cancellationToken);
        var matchedKeywords = GetMatchedIdentityKeywords(idText);
        var hasFaceLikeRegion = await TryDetectFaceLikeRegionAsync(idDocument, cancellationToken);
        var idLooksLikeIdentityDocument = matchedKeywords.Count >= 1 || hasFaceLikeRegion;

        if (string.IsNullOrWhiteSpace(idName))
        {
            warnings.Add("Could not extract a clear full name from the ID document.");
        }

        if (string.IsNullOrWhiteSpace(idPreviewBase64))
        {
            warnings.Add("Could not build an ID image preview from the uploaded file.");
        }

        if (!idLooksLikeIdentityDocument)
        {
            warnings.Add("Uploaded GovernmentId file does not look like an identity document or face photo.");
        }

        var bankText = await TryExtractTextWithTesseractAsync(bankStatementDocument, cancellationToken);
        var (balance, currency) = TryExtractBalance(bankText);
        var country = TryExtractCountry(bankText);

        if (balance == null)
        {
            warnings.Add("Could not extract a balance from the bank statement text.");
        }

        if (string.IsNullOrWhiteSpace(country))
        {
            warnings.Add("Could not detect a country from the bank statement text.");
        }

        return new DocumentExtractionResponse
        {
            ExtractedIdName = idName,
            IdImagePreviewBase64 = idPreviewBase64,
            IdNameMatchesExpected = true,
            IdLooksLikeIdentityDocument = idLooksLikeIdentityDocument,
            HasFaceLikeRegion = hasFaceLikeRegion,
            MatchedIdKeywords = matchedKeywords,
            IdTextPreview = BuildPreview(idText),
            ExtractedBankBalance = balance,
            ExtractedBankCurrency = currency,
            ExtractedBankCountry = country,
            BankTextPreview = BuildPreview(bankText),
            Warnings = warnings
        };
    }

    private static IReadOnlyCollection<string> GetMatchedIdentityKeywords(string text)
    {
        var normalized = Normalize(text);
        return IdentityKeywords
            .Where(keyword => normalized.Contains(Normalize(keyword), StringComparison.Ordinal))
            .Distinct()
            .ToArray();
    }

    private static async Task<bool> TryDetectImageDataAsync(IFormFile file, CancellationToken cancellationToken)
    {
        await using var stream = file.OpenReadStream();
        var info = await Image.IdentifyAsync(stream, cancellationToken);
        return info != null && info.Width > 0 && info.Height > 0;
    }

    private static async Task<string> TryExtractTextWithTesseractAsync(IFormFile file, CancellationToken cancellationToken)
    {
        var extension = Path.GetExtension(file.FileName);
        var tempPath = Path.Combine(Path.GetTempPath(), $"adoption-id-{Guid.NewGuid():N}{extension}");

        try
        {
            await using (var output = File.Create(tempPath))
            {
                await file.CopyToAsync(output, cancellationToken);
            }

            var psi = new ProcessStartInfo
            {
                FileName = "tesseract",
                Arguments = $"\"{tempPath}\" stdout --psm 6",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = psi };
            process.Start();

            var stdout = await process.StandardOutput.ReadToEndAsync(cancellationToken);
            var stderr = await process.StandardError.ReadToEndAsync(cancellationToken);
            await process.WaitForExitAsync(cancellationToken);

            if (process.ExitCode != 0)
            {
                return string.IsNullOrWhiteSpace(stderr) ? string.Empty : string.Empty;
            }

            return stdout;
        }
        catch
        {
            return string.Empty;
        }
        finally
        {
            if (File.Exists(tempPath))
            {
                File.Delete(tempPath);
            }
        }
    }

    private static async Task<string?> TryBuildPreviewBase64Async(IFormFile file, CancellationToken cancellationToken)
    {
        try
        {
            await using var stream = file.OpenReadStream();
            using var image = await Image.LoadAsync(stream, cancellationToken);
            image.Mutate(context => context.Resize(new ResizeOptions
            {
                Mode = ResizeMode.Max,
                Size = new Size(220, 140)
            }));

            await using var output = new MemoryStream();
            await image.SaveAsJpegAsync(output, new JpegEncoder { Quality = 75 }, cancellationToken);
            return "data:image/jpeg;base64," + Convert.ToBase64String(output.ToArray());
        }
        catch
        {
            return null;
        }
    }

    private static (decimal? balance, string? currency) TryExtractBalance(string text)
    {
        var matches = Regex.Matches(text, @"(?<currency>USD|EUR|RON|GBP|\$|€|£)?\s*(?<amount>\d{1,3}(?:[\., ]\d{3})*(?:[\.,]\d{2})?)", RegexOptions.IgnoreCase);
        if (matches.Count == 0)
        {
            return (null, null);
        }

        var best = matches
            .Select(match => new
            {
                Currency = match.Groups["currency"].Value,
                RawAmount = match.Groups["amount"].Value,
                Parsed = TryParseAmount(match.Groups["amount"].Value)
            })
            .Where(item => item.Parsed.HasValue)
            .OrderByDescending(item => item.Parsed!.Value)
            .FirstOrDefault();

        if (best == null)
        {
            return (null, null);
        }

        var normalizedCurrency = string.IsNullOrWhiteSpace(best.Currency) ? null : best.Currency.ToUpperInvariant();
        return (best.Parsed, normalizedCurrency);
    }

    private static decimal? TryParseAmount(string value)
    {
        var cleaned = value.Replace(" ", string.Empty);
        var standardized = cleaned.Replace(",", ".");

        if (decimal.TryParse(standardized, NumberStyles.Number, CultureInfo.InvariantCulture, out var result))
        {
            return result;
        }

        return null;
    }

    private static string? TryExtractCountry(string text)
    {
        var countries = new[]
        {
            "ROMANIA", "UNITED KINGDOM", "UK", "GERMANY", "FRANCE", "ITALY", "SPAIN", "NETHERLANDS", "BELGIUM", "PORTUGAL",
            "UNITED STATES", "USA", "CANADA", "POLAND", "AUSTRIA", "SWEDEN", "NORWAY", "DENMARK", "SWITZERLAND", "IRELAND"
        };

        var normalizedText = Normalize(text);
        return countries.FirstOrDefault(country => normalizedText.Contains(Normalize(country), StringComparison.Ordinal));
    }

    private static string? TryExtractNameCandidate(string extractedText)
    {
        var lines = extractedText
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(line => line.Length >= 5 && !line.Any(char.IsDigit));

        foreach (var line in lines)
        {
            var cleaned = Regex.Replace(line, "[^A-Za-z ]", " ").Trim();
            if (cleaned.Length < 5)
            {
                continue;
            }

            var words = cleaned.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (words.Length is < 2 or > 5)
            {
                continue;
            }

            if (words.Any(word => NameStopWords.Contains(word.ToUpperInvariant())))
            {
                continue;
            }

            if (words.Any(word => word.Length < 2))
            {
                continue;
            }

            return string.Join(' ', words);
        }

        return null;
    }

    private static async Task<bool> TryDetectFaceLikeRegionAsync(IFormFile file, CancellationToken cancellationToken)
    {
        try
        {
            await using var stream = file.OpenReadStream();
            using var image = await Image.LoadAsync<Rgba32>(stream, cancellationToken);

            // downscale to limit work
            var maxDim = 360;
            var scale = Math.Min(1.0, (double)maxDim / Math.Max(image.Width, image.Height));
            var w = Math.Max(1, (int)(image.Width * scale));
            var h = Math.Max(1, (int)(image.Height * scale));

            image.Mutate(x => x.Resize(new Size(w, h)));

            // build skin mask
            var mask = new bool[h, w];
            for (var y = 0; y < h; y++)
            {
                for (var x = 0; x < w; x++)
                {
                    var p = image[x, y];
                    mask[y, x] = IsSkinPixel(p);
                }
            }

            // find largest connected component
            var visited = new bool[h, w];
            var largest = 0;
            var largestBox = (minX: 0, minY: 0, maxX: 0, maxY: 0);

            var stack = new Stack<(int x, int y)>();
            for (var yy = 0; yy < h; yy++)
            {
                for (var xx = 0; xx < w; xx++)
                {
                    if (!mask[yy, xx] || visited[yy, xx]) continue;

                    var area = 0;
                    var minX = xx; var maxX = xx; var minY = yy; var maxY = yy;
                    stack.Push((xx, yy));
                    visited[yy, xx] = true;

                    while (stack.Count > 0)
                    {
                        var (cx, cy) = stack.Pop();
                        area++;
                        if (cx < minX) minX = cx;
                        if (cx > maxX) maxX = cx;
                        if (cy < minY) minY = cy;
                        if (cy > maxY) maxY = cy;

                        for (var oy = -1; oy <= 1; oy++)
                        for (var ox = -1; ox <= 1; ox++)
                        {
                            var nx = cx + ox;
                            var ny = cy + oy;
                            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                            if (visited[ny, nx] || !mask[ny, nx]) continue;
                            visited[ny, nx] = true;
                            stack.Push((nx, ny));
                        }
                    }

                    if (area > largest)
                    {
                        largest = area;
                        largestBox = (minX, minY, maxX, maxY);
                    }
                }
            }

            var total = w * h;
            if (largest <= 0) return false;

            var areaRatio = (double)largest / total;
            var boxW = largestBox.maxX - largestBox.minX + 1;
            var boxH = largestBox.maxY - largestBox.minY + 1;
            var boxAspect = boxW > 0 ? (double)boxH / boxW : 0.0;

            // heuristics for a face-like cluster
            var minAreaPixels = Math.Max(60, (int)(total * 0.003)); // at least ~0.3% of image
            var minBoxHeight = Math.Max(10, (int)(h * 0.08));

            var plausibleSize = largest >= minAreaPixels && boxH >= minBoxHeight;
            var plausibleShape = boxAspect is >= 0.4 and <= 2.5;

            return plausibleSize && plausibleShape && areaRatio >= 0.001;
        }
        catch
        {
            return false;
        }
    }

    private static bool IsSkinPixel(Rgba32 p)
    {
        // simple RGB-based skin detection heuristic suitable for demos
        var r = p.R;
        var g = p.G;
        var b = p.B;

        if (r < 60 || g < 40 || b < 20) return false;
        var max = Math.Max(r, Math.Max(g, b));
        var min = Math.Min(r, Math.Min(g, b));
        if (max - min < 15) return false;
        if (Math.Abs(r - g) < 15) return false;
        if (!(r > g && r > b)) return false;

        return true;
    }

    private static string BuildPreview(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        const int maxChars = 600;
        var normalized = Regex.Replace(text, "\\s+", " ").Trim();
        return normalized.Length <= maxChars ? normalized : normalized[..maxChars] + "...";
    }

    private static string Normalize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var sb = new StringBuilder(value.Length);
        foreach (var ch in value.ToUpperInvariant())
        {
            if (char.IsLetterOrDigit(ch) || ch == ' ')
            {
                sb.Append(ch);
            }
        }

        return Regex.Replace(sb.ToString(), "\\s+", " ").Trim();
    }
}