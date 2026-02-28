export default function TermsPage() {
  return (
    <main className="min-h-screen flex items-center justify-center bg-gray-50 py-8 px-2">
      <div className="w-full max-w-3xl bg-white rounded-xl shadow-lg p-8 md:p-12 border border-gray-200">
        <div className="prose prose-blue max-w-none prose-p:my-2 prose-ul:my-2 prose-li:my-1 prose-hr:my-4">
          <h1>Terms of Service</h1>
          <p>
            <em>Last Updated: February 17, 2026</em>
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">1. Acceptance of Terms</h2>
          <p>
            By accessing or using Deskly (&quot;Service&quot;), you agree to be
            bound by these Terms of Service (&quot;Terms&quot;). If you do not
            agree, do not use the Service. You must be at least 18 years old and
            legally capable of entering into a binding agreement.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">2. Description of Service</h2>
          <p>
            Deskly is an open-source, multi-tenant collaboration platform
            provided free of charge. The Service may be modified, suspended, or
            discontinued at any time without notice. No service-level guarantees
            are provided.
          </p>

          <hr className="my-6 border-gray-100" />
          <h2 className="text-xl font-semibold mt-8 mb-2 text-blue-600">
            3. Acceptable Use
          </h2>
          <ul>
            <li>Do not use the Service for unlawful purposes.</li>
            <li>Do not upload content you do not own or have rights to use.</li>
            <li>Do not upload illegal, infringing, or harmful content.</li>
            <li>Do not attempt to access other organizations’ data.</li>
            <li>Do not attempt to disrupt or compromise platform security.</li>
            <li>Do not abuse the Service using automated systems.</li>
          </ul>
          <p>
            We may remove content, suspend, or terminate accounts at our
            discretion.
          </p>

          <hr className="my-6 border-gray-100" />
          <h2 className="text-xl font-semibold mt-8 mb-2 text-blue-600">
            4. User Content
          </h2>
          <p>
            You retain ownership of content you upload. By uploading content,
            you grant Deskly a non-exclusive, worldwide, royalty-free license to
            host, store, process, and display that content solely to operate the
            Service.
          </p>
          <p>
            Uploaded images and public assets are publicly accessible. Do not
            upload sensitive or confidential information.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">5. Open Source</h2>
          <p>
            The source code of the Service is publicly available and governed by
            its applicable open-source license.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">6. Third-Party Services</h2>
          <p>
            The Service may link to third-party services. Deskly does not
            control those services and is not responsible for their content or
            practices.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">7. Disclaimer of Warranties</h2>
          <p>
            The Service is provided <strong>“as is”</strong> and{" "}
            <strong>“as available.”</strong>
            We disclaim all warranties, express or implied, including
            merchantability, fitness for a particular purpose, non-infringement,
            and uninterrupted access.
          </p>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">8. Limitation of Liability</h2>
          <p>
            To the fullest extent permitted by law, Deskly is not liable for
            indirect, incidental, or consequential damages, including loss of
            data or business. Total liability shall not exceed USD $100.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">9. Indemnification</h2>
          <p>
            You agree to indemnify and hold harmless Deskly from claims arising
            from your use of the Service, your violation of these Terms, or
            content you upload.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">10. Termination</h2>
          <p>
            We may suspend or terminate access at any time, with or without
            notice. You may stop using the Service at any time.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">11. Governing Law</h2>
          <p>
            These Terms are governed by the laws of India. Disputes shall be
            subject to the courts located in the state of the Service
            operator&apos;s residence in India.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">12. Changes</h2>
          <p>
            We may update these Terms at any time. Continued use constitutes
            acceptance of the updated Terms.
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">13. Contact</h2>
          <p>General & Legal inquiries: support@deskly.app</p>
        </div>
      </div>
    </main>
  );
}
