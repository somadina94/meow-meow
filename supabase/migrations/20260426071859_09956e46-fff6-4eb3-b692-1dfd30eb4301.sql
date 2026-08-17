-- Allow admins to manage files in legal-documents bucket
CREATE POLICY "Admins can upload legal documents"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'legal-documents' AND public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update legal documents"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'legal-documents' AND public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete legal documents"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'legal-documents' AND public.has_role(auth.uid(), 'admin'::app_role));

-- Set bucket size limit and allowed types
UPDATE storage.buckets 
SET file_size_limit = 20971520,
    allowed_mime_types = ARRAY['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/plain','text/html']
WHERE id = 'legal-documents';

-- Enable realtime for legal_documents table
ALTER TABLE public.legal_documents REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.legal_documents;

-- Auto-deactivate other versions of the same document_type when one is set active
CREATE OR REPLACE FUNCTION public.deactivate_other_legal_versions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_active = true THEN
    UPDATE public.legal_documents
    SET is_active = false, updated_at = now()
    WHERE document_type = NEW.document_type
      AND id <> NEW.id
      AND is_active = true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deactivate_other_legal_versions ON public.legal_documents;
CREATE TRIGGER trg_deactivate_other_legal_versions
AFTER INSERT OR UPDATE OF is_active ON public.legal_documents
FOR EACH ROW
WHEN (NEW.is_active = true)
EXECUTE FUNCTION public.deactivate_other_legal_versions();