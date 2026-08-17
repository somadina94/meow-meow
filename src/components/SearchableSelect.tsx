import { useState, useRef, useEffect } from "react";
import { Check, ChevronDown, Search } from "lucide-react";
import { cn } from "@/lib/utils";

interface Option {
  value: string;
  label: string;
  sublabel?: string;
  icon?: string;
}

interface SearchableSelectProps {
  options: Option[];
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  searchPlaceholder?: string;
  className?: string;
}

const SearchableSelect = ({
  options,
  value,
  onChange,
  placeholder,
  searchPlaceholder = "Search...",
  className,
}: SearchableSelectProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const containerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const selectedOption = options.find((opt) => opt.value === value);

  const filteredOptions = options.filter(
    (opt) =>
      opt.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
      opt.sublabel?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
        setSearchQuery("");
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  return (
    <div ref={containerRef} className={cn("relative", className)}>
      {/* Trigger */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className={cn(
          "w-full flex items-center justify-between gap-3 px-4 py-4 rounded-2xl",
          "bg-card border-2 border-border/50 shadow-card",
          "transition-all duration-300",
          "hover:border-primary/30 hover:shadow-soft",
          isOpen && "border-primary shadow-soft",
          "focus:outline-none focus:border-primary focus:shadow-soft"
        )}
      >
        <div className="flex items-center gap-3">
          {selectedOption?.icon && (
            <span className="text-2xl">{selectedOption.icon}</span>
          )}
          <span className={cn(
            "font-medium",
            selectedOption ? "text-foreground" : "text-muted-foreground"
          )}>
            {selectedOption ? selectedOption.label : placeholder}
          </span>
        </div>
        <ChevronDown
          className={cn(
            "w-5 h-5 text-muted-foreground transition-transform duration-300",
            isOpen && "rotate-180"
          )}
        />
      </button>

      {/* Dropdown */}
      {isOpen && (
        <div className="absolute z-50 w-full mt-2 py-2 bg-popover border border-border rounded-2xl shadow-card animate-slide-up">
          {/* Search input */}
          <div className="px-3 pb-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input
                ref={inputRef}
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder={searchPlaceholder}
                className="w-full pl-10 pr-4 py-2.5 bg-muted/50 rounded-xl text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/20"
              />
            </div>
          </div>

          {/* Options list */}
          <div className="max-h-64 overflow-y-auto">
            {filteredOptions.length === 0 ? (
              <div className="px-4 py-3 text-sm text-muted-foreground text-center">
                No results found
              </div>
            ) : (
              filteredOptions.map((option, index) => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => {
                    onChange(option.value);
                    setIsOpen(false);
                    setSearchQuery("");
                  }}
                  className={cn(
                    "w-full flex items-center justify-between gap-3 px-4 py-3",
                    "transition-colors duration-200",
                    "hover:bg-accent",
                    value === option.value && "bg-primary/5",
                    index === 0 && "animate-slide-in-right"
                  )}
                  style={{ animationDelay: `${index * 20}ms` }}
                >
                  <div className="flex items-center gap-3">
                    {option.icon && (
                      <span className="text-xl">{option.icon}</span>
                    )}
                    <div className="text-left">
                      <div className="font-medium text-foreground">{option.label}</div>
                      {option.sublabel && (
                        <div className="text-xs text-muted-foreground">{option.sublabel}</div>
                      )}
                    </div>
                  </div>
                  {value === option.value && (
                    <Check className="w-5 h-5 text-primary" />
                  )}
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default SearchableSelect;
