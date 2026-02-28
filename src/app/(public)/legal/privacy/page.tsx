export default function PrivacyPage() {
  return (
    <main className="min-h-screen flex items-center justify-center bg-gray-50 py-8 px-2">
      <div className="w-full max-w-3xl bg-white rounded-xl shadow-lg p-8 md:p-12 border border-gray-200">
        <div className="prose prose-blue max-w-none prose-p:my-2 prose-ul:my-2 prose-li:my-1 prose-hr:my-4">
          <h1>Privacy Policy</h1>
          <p>
            <em>Last Updated: February 17, 2026</em>
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">1. Data Controller</h2>
          <p>
            Deskly is the data controller for personal data processed through
            the Service. Contact: support@deskly.app
          </p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">2. Data We Collect</h2>
          <h3>Account Data</h3>
          <ul>
            <li>Email address</li>
            <li>Display name</li>
            <li>Organization association</li>
          </ul>

          <h3>User Content</h3>
          <ul>
            <li>Uploaded images</li>
            <li>Workspace configuration data</li>
            <li>Collaboration and presence metadata</li>
          </ul>
          <p>Uploaded images are publicly accessible.</p>

          <h3>Authentication</h3>
          <p>Login/session cookie only. No tracking or advertising cookies.</p>

          <h3>Logs</h3>
          <p>
            IP address, timestamps, and basic request metadata. Retained up to
            90 days.
          </p>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">3. Legal Basis (GDPR)</h2>
          <p>
            Processing is based on contractual necessity, legitimate interests
            (security and abuse prevention), or legal obligations where
            applicable.
          </p>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">4. Use of Data</h2>
          <ul>
            <li>Provide and operate the Service</li>
            <li>Authenticate users</li>
            <li>Maintain tenant isolation</li>
            <li>Prevent abuse</li>
            <li>Troubleshoot issues</li>
          </ul>
          <p>We do not sell personal data.</p>

          <hr className="my-2 border-gray-100" />
          <h2 className="text-blue-600">
            5. Infrastructure & International Transfers
          </h2>
          <p>
            The Service uses third-party hosting providers such as Vercel and
            Supabase. Data may be processed outside your country, including the
            United States. Transfers rely on lawful mechanisms such as Standard
            Contractual Clauses where required.
          </p>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">6. Retention</h2>
          <ul>
            <li>Account data retained until deletion</li>
            <li>Logs retained up to 90 days</li>
            <li>Backups may temporarily persist before deletion cycles</li>
          </ul>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">7. Your Rights</h2>
          <p>
            Depending on your jurisdiction, you may request access, correction,
            deletion, restriction, objection, or data portability. Contact:
            support@deskly.app
          </p>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">8. Security</h2>
          <p>
            We implement reasonable safeguards including HTTPS, access controls,
            and tenant isolation. No system is completely secure.
          </p>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">9. Children</h2>
          <p>The Service is not intended for individuals under 18.</p>

          <hr className="border-gray-100" />
          <h2 className="text-blue-600">10. Changes</h2>
          <p>We may update this policy at any time.</p>
        </div>
      </div>
    </main>
  );
}
