-- Create legal_documents table for tracking legal documents
CREATE TABLE public.legal_documents (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  document_type TEXT NOT NULL DEFAULT 'terms',
  version TEXT NOT NULL DEFAULT '1.0',
  description TEXT,
  file_path TEXT NOT NULL,
  file_size BIGINT,
  mime_type TEXT,
  is_active BOOLEAN NOT NULL DEFAULT false,
  uploaded_by UUID,
  effective_date DATE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

-- Anyone can view active legal documents
CREATE POLICY "Anyone can view active legal documents"
ON public.legal_documents
FOR SELECT
USING (is_active = true);

-- Admins can view all legal documents
CREATE POLICY "Admins can view all legal documents"
ON public.legal_documents
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- Admins can insert legal documents
CREATE POLICY "Admins can insert legal documents"
ON public.legal_documents
FOR INSERT
WITH CHECK (has_role(auth.uid(), 'admin'));

-- Admins can update legal documents
CREATE POLICY "Admins can update legal documents"
ON public.legal_documents
FOR UPDATE
USING (has_role(auth.uid(), 'admin'));

-- Admins can delete legal documents
CREATE POLICY "Admins can delete legal documents"
ON public.legal_documents
FOR DELETE
USING (has_role(auth.uid(), 'admin'));

-- Create indexes
CREATE INDEX idx_legal_documents_type ON public.legal_documents(document_type);
CREATE INDEX idx_legal_documents_active ON public.legal_documents(is_active);
CREATE INDEX idx_legal_documents_version ON public.legal_documents(name, version);

-- Add updated_at trigger
CREATE TRIGGER update_legal_documents_updated_at
BEFORE UPDATE ON public.legal_documents
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Create storage bucket for legal documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('legal-documents', 'legal-documents', true);

-- Storage policies for legal documents bucket
CREATE POLICY "Anyone can view legal documents"
ON storage.objects
FOR SELECT
USING (bucket_id = 'legal-documents');

CREATE POLICY "Admins can upload legal documents"
ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'legal-documents' AND has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update legal documents"
ON storage.objects
FOR UPDATE
USING (bucket_id = 'legal-documents' AND has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete legal documents"
ON storage.objects
FOR DELETE
USING (bucket_id = 'legal-documents' AND has_role(auth.uid(), 'admin'));