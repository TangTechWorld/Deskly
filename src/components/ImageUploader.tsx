import { Image as ImageIcon, Link as LinkIcon, Upload, X } from "lucide-react";
import Image from "next/image";
import { useState } from "react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";

interface ImageUploaderProps {
  value?: string; // Current image URL or preview
  onChange: (imageUrl: string, file?: File) => void;
  label?: string;
  previewSize?: "sm" | "md" | "lg";
  previewShape?: "square" | "circle";
  fallbackIcon?: React.ReactNode;
  fallbackText?: string;
  acceptedFormats?: string;
  maxSizeText?: string;
  placeholder?: string;
}

export function ImageUploader({
  value = "",
  onChange,
  label = "Image",
  previewSize = "md",
  previewShape = "square",
  fallbackIcon,
  fallbackText = "No image",
  acceptedFormats = "image/*",
  maxSizeText = "PNG, JPG, or GIF up to 2MB",
  placeholder = "https://example.com/image.png",
}: ImageUploaderProps) {
  const [uploadType, setUploadType] = useState<"upload" | "url">("upload");
  const [urlInput, setUrlInput] = useState(
    value.startsWith("http") ? value : "",
  );
  const [filePreview, setFilePreview] = useState(
    value && !value.startsWith("http") ? value : "",
  );
  const [fileName, setFileName] = useState("");

  // Size mappings
  const sizeClasses = {
    sm: "w-20 h-20",
    md: "w-32 h-32",
    lg: "w-40 h-40",
  };

  const iconSizes = {
    sm: "w-8 h-8",
    md: "w-12 h-12",
    lg: "w-16 h-16",
  };

  const shapeClasses =
    previewShape === "circle" ? "rounded-full" : "rounded-xl";

  const handleUploadTypeChange = (type: "upload" | "url") => {
    setUploadType(type);
    if (type === "url") {
      setFilePreview("");
      setFileName("");
    } else {
      setUrlInput("");
    }
  };

  const handleUrlChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const url = e.target.value;
    setUrlInput(url);
    if (url.startsWith("https://")) {
      onChange(url);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setFileName(file.name);
      const preview = URL.createObjectURL(file);
      setFilePreview(preview);
      onChange(preview, file);
    }
  };

  const handleRemove = () => {
    setFilePreview("");
    setUrlInput("");
    setFileName("");
    onChange("");
  };

  const currentPreview =
    filePreview ||
    (uploadType === "url" && urlInput.startsWith("https://") ? urlInput : "");

  return (
    <div className="space-y-3">
      {label && <Label>{label}</Label>}

      {/* Preview - Always Visible */}
      <div className="flex justify-center">
        <div className="relative">
          {currentPreview ? (
            <div
              className={`${sizeClasses[previewSize]} ${shapeClasses} border-2 border-gray-200 overflow-hidden bg-white shadow-sm`}
            >
              <Image
                src={currentPreview}
                alt="Preview"
                width={32}
                height={32}
                className="w-full h-full object-cover"
                onError={(e) => {
                  (e.target as HTMLImageElement).src = "";
                  (e.target as HTMLImageElement).style.display = "none";
                }}
                unoptimized
              />
            </div>
          ) : (
            <div
              className={`${sizeClasses[previewSize]} ${shapeClasses} border-2 border-dashed border-gray-300 bg-gray-50 flex flex-col items-center justify-center`}
            >
              {fallbackIcon ?? (
                <ImageIcon
                  className={`${iconSizes[previewSize]} text-gray-400 mb-1`}
                />
              )}
              <span className="text-xs text-gray-500 mt-1">{fallbackText}</span>
            </div>
          )}
          {currentPreview && (
            <Button
              type="button"
              variant="destructive"
              size="sm"
              className="absolute -top-2 -right-2 h-7 w-7 rounded-full p-0 shadow-md"
              onClick={handleRemove}
            >
              <X className="w-4 h-4" />
            </Button>
          )}
        </div>
      </div>

      {/* Upload/URL Controls */}
      <div className="space-y-3">
        {/* Tab buttons */}
        <div className="flex gap-2 p-1 bg-gray-100 rounded-lg">
          <button
            type="button"
            onClick={() => handleUploadTypeChange("upload")}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-md text-sm transition-colors ${
              uploadType === "upload"
                ? "bg-white shadow-sm text-blue-600 font-medium"
                : "text-gray-600 hover:text-gray-900"
            }`}
          >
            <Upload className="w-4 h-4" />
            Upload
          </button>
          <button
            type="button"
            onClick={() => handleUploadTypeChange("url")}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-md text-sm transition-colors ${
              uploadType === "url"
                ? "bg-white shadow-sm text-blue-600 font-medium"
                : "text-gray-600 hover:text-gray-900"
            }`}
          >
            <LinkIcon className="w-4 h-4" />
            URL
          </button>
        </div>

        {/* Upload section */}
        {uploadType === "upload" && (
          <div>
            <Input
              id={`file-upload-${label}`}
              type="file"
              accept={acceptedFormats}
              onChange={handleFileChange}
              className="hidden"
            />
            <label
              htmlFor={`file-upload-${label}`}
              className="flex items-center justify-center gap-2 px-4 py-3 border-2 border-dashed border-gray-300 rounded-lg hover:border-blue-400 hover:bg-blue-50/50 transition-all cursor-pointer"
            >
              <ImageIcon className="w-5 h-5 text-gray-500" />
              <span className="text-sm text-gray-700">
                {fileName || "Choose image file"}
              </span>
            </label>
            <p className="text-xs text-gray-500 mt-2 text-center">
              {maxSizeText}
            </p>
          </div>
        )}

        {/* URL section */}
        {uploadType === "url" && (
          <div>
            <Input
              id={`url-upload-${label}`}
              value={urlInput}
              onChange={handleUrlChange}
              placeholder={placeholder}
              type="url"
            />
            {urlInput && !urlInput.startsWith("https://") && (
              <p className="text-xs text-amber-600 flex items-center gap-1 mt-2">
                <span>⚠️</span>
                URL must start with https://
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
