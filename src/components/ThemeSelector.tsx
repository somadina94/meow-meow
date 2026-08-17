import { useState } from 'react';
import { useAppTheme, THEMES, ThemeId, ThemeMode } from '@/contexts/ThemeContext';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import { Check, Sun, Moon, Monitor, Palette, ChevronDown, ChevronUp } from 'lucide-react';

const MODE_OPTIONS: { id: ThemeMode; icon: typeof Sun; label: string }[] = [
  { id: 'light', icon: Sun, label: 'Light' },
  { id: 'dark', icon: Moon, label: 'Dark' },
  { id: 'system', icon: Monitor, label: 'System' },
];

interface ThemeSelectorProps {
  compact?: boolean;
}

export function ThemeSelector({ compact = false }: ThemeSelectorProps) {
  const { themeId, mode, setTheme, setMode } = useAppTheme();
  const t = (key: string, def: string) => def;
  const [showAllThemes, setShowAllThemes] = useState(false);
  
  const themeEntries = Object.entries(THEMES) as [ThemeId, typeof THEMES[ThemeId]][];
  const displayedThemes = showAllThemes ? themeEntries : themeEntries.slice(0, 8);

  if (compact) {
    return (
      <div className="space-y-6">
        {/* Theme Mode */}
        <div className="space-y-3">
          <Label className="text-sm font-medium">{t('theme', 'Theme Mode')}</Label>
          <div className="grid grid-cols-3 gap-3">
            {MODE_OPTIONS.map((option) => {
              const Icon = option.icon;
              return (
                <button
                  key={option.id}
                  onClick={() => setMode(option.id)}
                  className={cn(
                    "flex flex-col items-center justify-center p-4 rounded-xl border-2 transition-all duration-200",
                    mode === option.id
                      ? "border-primary bg-primary/10"
                      : "border-border hover:border-primary/50"
                  )}
                >
                  <Icon className={cn(
                    "h-6 w-6 mb-2",
                    mode === option.id ? "text-primary" : "text-muted-foreground"
                  )} />
                  <span className={cn(
                    "text-sm font-medium",
                    mode === option.id ? "text-primary" : "text-muted-foreground"
                  )}>
                    {t(option.id, option.label)}
                  </span>
                  {mode === option.id && (
                    <Check className="h-4 w-4 text-primary mt-1" />
                  )}
                </button>
              );
            })}
          </div>
        </div>

        <Separator />

        {/* Color Theme */}
        <div className="space-y-3">
          <Label className="text-sm font-medium">{t('colorTheme', 'Color Theme')}</Label>
          <div className="grid grid-cols-4 gap-3">
            {displayedThemes.map(([id, theme]) => (
              <button
                key={id}
                onClick={() => setTheme(id)}
                className={cn(
                  "relative flex flex-col items-center gap-2 p-3 rounded-xl border-2 transition-all duration-200",
                  themeId === id
                    ? "border-primary bg-primary/5"
                    : "border-border hover:border-primary/50"
                )}
                title={theme.description}
              >
                {/* Color Preview */}
                <div className="flex gap-1">
                  <div 
                    className="w-4 h-4 rounded-full shadow-sm"
                    style={{ backgroundColor: `hsl(${theme.preview.primary})` }}
                  />
                  <div 
                    className="w-4 h-4 rounded-full shadow-sm"
                    style={{ backgroundColor: `hsl(${theme.preview.accent})` }}
                  />
                </div>
                <span className={cn(
                  "text-xs font-medium truncate w-full text-center",
                  themeId === id ? "text-primary" : "text-muted-foreground"
                )}>
                  {theme.name}
                </span>
                {themeId === id && (
                  <Check className="absolute top-1 right-1 h-3 w-3 text-primary" />
                )}
              </button>
            ))}
          </div>
          
          {themeEntries.length > 8 && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setShowAllThemes(!showAllThemes)}
              className="w-full mt-2"
            >
              {showAllThemes ? (
                <>
                  <ChevronUp className="h-4 w-4 mr-2" />
                  {t('showLess', 'Show Less')}
                </>
              ) : (
                <>
                  <ChevronDown className="h-4 w-4 mr-2" />
                  {t('showAll', 'Show All')} ({themeEntries.length} {t('themes', 'themes')})
                </>
              )}
            </Button>
          )}
        </div>
      </div>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center gap-2 text-lg">
          <Palette className="h-5 w-5 text-primary" />
          {t('appearance', 'Appearance')}
        </CardTitle>
        <CardDescription>{t('customizeAppLooks', 'Customize how the app looks')}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Theme Mode */}
        <div className="space-y-3">
          <Label className="text-sm font-medium">{t('theme', 'Theme Mode')}</Label>
          <div className="grid grid-cols-3 gap-3">
            {MODE_OPTIONS.map((option) => {
              const Icon = option.icon;
              return (
                <button
                  key={option.id}
                  onClick={() => setMode(option.id)}
                  className={cn(
                    "flex flex-col items-center justify-center p-4 rounded-xl border-2 transition-all duration-200",
                    mode === option.id
                      ? "border-primary bg-primary/10"
                      : "border-border hover:border-primary/50"
                  )}
                >
                  <Icon className={cn(
                    "h-6 w-6 mb-2",
                    mode === option.id ? "text-primary" : "text-muted-foreground"
                  )} />
                  <span className={cn(
                    "text-sm font-medium",
                    mode === option.id ? "text-primary" : "text-muted-foreground"
                  )}>
                    {t(option.id, option.label)}
                  </span>
                  {mode === option.id && (
                    <Check className="h-4 w-4 text-primary mt-1" />
                  )}
                </button>
              );
            })}
          </div>
        </div>

        <Separator />

        {/* Color Theme Grid */}
        <div className="space-y-3">
          <Label className="text-sm font-medium">{t('colorTheme', 'Color Theme')}</Label>
          <ScrollArea className="h-64">
            <div className="grid grid-cols-2 gap-3 pr-4">
              {themeEntries.map(([id, theme]) => (
                <button
                  key={id}
                  onClick={() => setTheme(id)}
                  className={cn(
                    "relative flex flex-col items-start gap-2 p-4 rounded-xl border-2 transition-all duration-200 text-left",
                    themeId === id
                      ? "border-primary bg-primary/5"
                      : "border-border hover:border-primary/50"
                  )}
                >
                  {/* Color Preview */}
                  <div className="flex gap-1.5">
                    <div 
                      className="w-6 h-6 rounded-full shadow-sm ring-1 ring-border/50"
                      style={{ backgroundColor: `hsl(${theme.preview.primary})` }}
                    />
                    <div 
                      className="w-6 h-6 rounded-full shadow-sm ring-1 ring-border/50"
                      style={{ backgroundColor: `hsl(${theme.preview.accent})` }}
                    />
                    <div 
                      className="w-6 h-6 rounded-full shadow-sm ring-1 ring-border/50"
                      style={{ backgroundColor: `hsl(${theme.preview.secondary})` }}
                    />
                  </div>
                  
                  <div>
                    <p className={cn(
                      "text-sm font-medium",
                      themeId === id ? "text-primary" : "text-foreground"
                    )}>
                      {theme.name}
                    </p>
                    <p className="text-xs text-muted-foreground line-clamp-1">
                      {theme.description}
                    </p>
                  </div>
                  
                  {themeId === id && (
                    <Check className="absolute top-2 right-2 h-4 w-4 text-primary" />
                  )}
                </button>
              ))}
            </div>
          </ScrollArea>
        </div>
      </CardContent>
    </Card>
  );
}
