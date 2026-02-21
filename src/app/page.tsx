import { Login } from "@/components/Login";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Button } from "@/components/ui/button";
import { Globe, MessageSquare, Shield, Users, Video, Zap } from "lucide-react";
import Image from "next/image";

export default function LandingPage() {
  return (
    <div>
      <section className="container mx-auto px-4 py-20 text-center">
        <h1 className="text-5xl font-bold mb-6 bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
          Your Team&apos;s Spatial Presence Layer
        </h1>
        <p className="text-xl text-gray-600 mb-8 max-w-2xl mx-auto">
          Know where your teammates are, what they&apos;re working on, and join
          them instantly. Link-based collaboration that feels natural.
        </p>
        <div className="max-w-4xl mx-auto rounded-lg shadow-2xl overflow-hidden">
          <Image
            src="/collaborate.png"
            alt="Team collaboration"
            className="w-full"
            width={1200}
            height={600}
          />
        </div>
      </section>

      <section className="container mx-auto px-4 py-20">
        <h2 className="text-3xl font-bold text-center mb-12">
          Everything you need for spatial collaboration
        </h2>
        <div className="grid md:grid-cols-3 gap-8">
          <FeatureCard
            icon={<Video className="w-8 h-8" />}
            title="Instant Meetings"
            description="Join any desk or room instantly. No scheduling needed. Works with Google Meet, Zoom, Teams, or any meeting platform."
          />
          <FeatureCard
            icon={<Users className="w-8 h-8" />}
            title="Real-time Presence"
            description="See who's at their desk, in a meeting, or focusing. Know the best time to reach out or join a conversation."
          />
          <FeatureCard
            icon={<Zap className="w-8 h-8" />}
            title="Quick Interactions"
            description="Ring a desk to get someone's attention, knock before joining a room, or invite teammates to your space."
          />
          <FeatureCard
            icon={<Globe className="w-8 h-8" />}
            title="Vendor Neutral"
            description="Use your existing meeting links. No lock-in to specific video platforms. Works with what your team already uses."
          />
          <FeatureCard
            icon={<MessageSquare className="w-8 h-8" />}
            title="Status & Context"
            description="Set custom messages, show availability, and give teammates context about what you're working on."
          />
          <FeatureCard
            icon={<Shield className="w-8 h-8" />}
            title="Multi-tenant Ready"
            description="Perfect for organizations of any size. Secure, isolated workspaces with admin controls and permissions."
          />
        </div>
      </section>

      <section className="bg-blue-50 py-20">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center mb-12">How it works</h2>
          <div className="max-w-3xl mx-auto space-y-8">
            <Step
              number={1}
              title="Create your organization"
              description="Set up your workspace and invite your team members."
            />
            <Step
              number={2}
              title="Design your spatial map"
              description="Add desks, meeting rooms, and focus pods. Assign team members to their spaces."
            />
            <Step
              number={3}
              title="Add meeting links"
              description="Connect your existing Google Meet, Zoom, or Teams links to each space."
            />
            <Step
              number={4}
              title="Go live"
              description="Your team can now see presence, move between spaces, and join meetings instantly."
            />
          </div>
        </div>
      </section>

      <section className="container mx-auto px-4 py-20">
        <h2 className="text-3xl font-bold text-center mb-12">
          Frequently Asked Questions
        </h2>
        <div className="max-w-2xl mx-auto">
          <Accordion type="single" collapsible>
            <AccordionItem value="item-1">
              <AccordionTrigger>
                What meeting platforms are supported?
              </AccordionTrigger>
              <AccordionContent>
                Deskly is vendor-neutral and works with any link-based meeting
                platform including Google Meet, Zoom, Microsoft Teams, Whereby,
                and more. Simply paste your meeting link into any desk or room.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-2">
              <AccordionTrigger>
                How does real-time presence work?
              </AccordionTrigger>
              <AccordionContent>
                When you&apos;re logged in, your status is automatically updated
                as you move between desks and rooms. You can set your status to
                active, in a meeting, away, or do not disturb. Custom status
                messages are also supported.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-3">
              <AccordionTrigger>
                Can I customize the map layout?
              </AccordionTrigger>
              <AccordionContent>
                Yes! Organization admins can upload custom map backgrounds, add
                desks and rooms, position them anywhere on the map, and
                customize names and meeting links for each space.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-4">
              <AccordionTrigger>
                Is this suitable for remote teams?
              </AccordionTrigger>
              <AccordionContent>
                Absolutely. Deskly is designed for remote and hybrid teams to
                create a sense of presence and spatial awareness that
                traditional chat tools can&apos;t provide. It works great for
                fully remote, hybrid, and in-office teams.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-5">
              <AccordionTrigger>
                What about privacy and security?
              </AccordionTrigger>
              <AccordionContent>
                Each organization has isolated data. Users can only see presence
                and interact with members of their own organization. We
                don&apos;t access your meeting links or record any calls - we
                simply facilitate the connections.
              </AccordionContent>
            </AccordionItem>
          </Accordion>
        </div>
      </section>

      <section className="bg-gradient-to-r from-blue-600 to-purple-600 text-white py-12">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-4xl font-bold mb-4">
            Ready to transform how your team collaborates?
          </h2>
          <p className="mb-8 text-xl opacity-90">
            Join teams who are creating better remote work experiences.
          </p>
          <Login>
            <Button size="lg" variant="secondary">
              Get Started for Free
            </Button>
          </Login>
        </div>
      </section>
    </div>
  );
}

function FeatureCard({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="p-6 bg-white rounded-lg border shadow-sm hover:shadow-md transition-shadow">
      <div className="text-blue-600 mb-4">{icon}</div>
      <h3 className="font-semibold mb-2">{title}</h3>
      <p className="text-sm text-gray-600">{description}</p>
    </div>
  );
}

function Step({
  number,
  title,
  description,
}: {
  number: number;
  title: string;
  description: string;
}) {
  return (
    <div className="flex gap-4">
      <div className="flex-shrink-0 w-10 h-10 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold">
        {number}
      </div>
      <div>
        <h3 className="font-semibold mb-1">{title}</h3>
        <p className="text-gray-600">{description}</p>
      </div>
    </div>
  );
}
