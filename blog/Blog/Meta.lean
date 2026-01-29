import VersoBlog

open Verso Genre Blog
open Template

open Verso.Output.Html

def greeterCss : String :=
r#"

.greeter-container {
    position: relative;
    height: 70vh;
    display: flex;
    align-items: center;
    justify-content: center;
    perspective: 1000px;
}

.floating-math {
    position: absolute;
    opacity: 0.4;
    font-size: 1.2rem;
    animation: float 8s ease-in-out infinite;
    color: #64748b;
    font-family: 'Courier New', Courier, monospace;
}

.floating-math:nth-child(1) { top: 10%; left: 10%; animation-delay: 0s; }
.floating-math:nth-child(2) { top: 20%; right: 15%; animation-delay: -2s; }
.floating-math:nth-child(3) { bottom: 30%; left: 5%; animation-delay: -4s; }
.floating-math:nth-child(4) { bottom: 15%; right: 10%; animation-delay: -6s; }
.floating-math:nth-child(5) { top: 50%; left: 3%; animation-delay: -1s; }
.floating-math:nth-child(6) { top: 60%; right: 5%; animation-delay: -3s; }

@keyframes float {
    0%, 100% { transform: translateY(0px) rotate(0deg); opacity: 0.3; }
    25% { transform: translateY(-20px) rotate(2deg); opacity: 0.5; }
    50% { transform: translateY(-10px) rotate(-1deg); opacity: 0.4; }
    75% { transform: translateY(-15px) rotate(1deg); opacity: 0.3; }
}

.greeter {
    text-align: center;
    z-index: 10;
    max-width: 800px;
    padding: 2rem;
}

.greeter .title {
    font-size: 4rem;
    font-weight: bold;
    margin-bottom: 1rem;
    font-family: 'Courier New', Courier, monospace;
    background: linear-gradient(45deg, #3b82f6, #8b5cf6, #06b6d4);
    background-size: 200% 200%;
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    animation: gradient-shift 4s ease-in-out infinite;
    text-shadow: 0 0 30px rgba(59, 130, 246, 0.3);
}

@keyframes gradient-shift {
    0%, 100% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
}

.greeter:not(:first-child) {
    font-size: 1.3rem;
    color: #475569;
    margin-bottom: 2rem;
    opacity: 0;
    animation: fade-in 2s ease-out 0.5s forwards;
}

@keyframes fade-in {
    to { opacity: 1; }
}

.particles {
    position: absolute;
    width: 100%;
    height: 100%;
    overflow: hidden;
}

.particle {
    position: absolute;
    width: 2px;
    height: 2px;
    background: #3b82f6;
    border-radius: 50%;
    animation: particle-float 15s linear infinite;
    opacity: 0.6;
}

@keyframes particle-float {
    0% {
        transform: translateY(100vh) translateX(0);
        opacity: 0;
    }
    10% {
        opacity: 1;
    }
    90% {
        opacity: 1;
    }
    100% {
        transform: translateY(-10vh) translateX(50px);
        opacity: 0;
    }
}
"#

def greeterJs :=
r#"
function initGreeter() {
    // Create floating particles
    function createParticle() {
        const particle = document.createElement('div');
        particle.className = 'particle';
        particle.style.left = Math.random() * 100 + '%';
        particle.style.animationDelay = Math.random() * 15 + 's';
        particle.style.animationDuration = (15 + Math.random() * 10) + 's';
        let elem = document.getElementById('particles');
        if (elem) {
            elem.appendChild(particle);

            // Remove particle after animation
            setTimeout(() => {
                if (particle.parentNode) {
                    particle.parentNode.removeChild(particle);
                }
            }, 25000);
        }
    }

    // Create particles periodically
    setInterval(createParticle, 800);

    // Initial particles
    for (let i = 0; i < 10; i++) {
        setTimeout(createParticle, i * 100);
    }

    // Add mouse interaction
    const title = document.querySelector('.title');
    if (title) {
        document.addEventListener('mousemove', (e) => {
            const rect = title.getBoundingClientRect();
            const x = e.clientX - rect.left - rect.width / 2;
            const y = e.clientY - rect.top - rect.height / 2;

            const rotateX = y / rect.height * 10;
            const rotateY = -x / rect.width * 10;

            title.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
        });

        // Reset title rotation when mouse leaves
        document.addEventListener('mouseleave', () => {
            const title = document.querySelector('.title');
            title.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg)';
        });
    }
}
"#

/--
Displays an animated greeter for the front page of the blog.
-/
block_component +directive greeter where
  toHtml id _data _goI goB contents := do
    saveJs <| "if (document.getElementById('" ++ id ++ "')) { initGreeter(); }"
    pure {{
    <div class="greeter-container" id={{id}}>
        <div class="particles" id="particles"></div>

        <div class="floating-math">"∀ n : ℕ, P n → P (n + 1)"</div>
        <div class="floating-math">"theorem ∘ proof ∘ verification"</div>
        <div class="floating-math">"λ x. f (g x)"</div>
        <div class="floating-math">"#check #eval #reduce"</div>
        <div class="floating-math">"∃ k, n = 2 * k"</div>
        <div class="floating-math">"by induction n with"</div>



        <div class="greeter">
            <h1 class="title">"Axiomatizing Alex"</h1>
            {{← contents.mapM goB}}
        </div>
    </div>
    }}

  cssFiles := #[("greeter.css", greeterCss)]
  jsFiles := #[("greeter.js", greeterJs)]

open Verso.Output

instance [MonadLift m m'] [Monad m'] [MonadConfig m] : MonadConfig m' where
  currentConfig := do
    let x : Config ← (currentConfig : m Config)
    pure x

/--
Adds navigation breadcrumbs to a template, if the current path is at least as long as `threshold`.
-/
def breadcrumbs (threshold : Nat) : Template := do
  if (← read).path.size ≥ threshold then
    let some pathTitles ← parents (← read).site (← read).path.toList
      | pure .empty
    pure {{
      <nav class="breadcrumbs" role="navigation">
        <ol>
          {{ crumbLinks pathTitles |>.map ({{<li>{{·}}</li>}}) }}
        </ol>
      </nav>
    }}
  else pure .empty
where
  crumbLinks (titles : List String) : List Html := go titles.length titles
  go
    | 0, xs | 1, xs => xs.map Html.ofString
    | _, [] => []
    | n+1, x::xs =>
      let path := String.join <| List.replicate n "../"
      {{<a href={{path}}>{{x}}</a>}} :: go n xs

  parents (s : Site) (path : List String) : OptionT TemplateM (List String) :=
    match s with
    | .page _ _ contents => dirParents contents path
    | .blog _ _ contents => blogParents contents path

  dirParents (d : Array Dir) : (path : List String) → OptionT TemplateM (List String)
    | [] => pure []
    | p :: ps => do
      match d.find? (·.name == p) with
      | some (.page _ _ txt contents) => (txt.titleString :: ·) <$> dirParents contents ps
      | some (.blog _ _ txt contents) => (txt.titleString :: ·) <$> blogParents contents ps
      | some (.static ..) | none => failure

  blogParents (posts : Array BlogPost) : (path : List String) → OptionT TemplateM (List String)
    | [] => pure []
    | [p] => do
      match ← posts.findM? (fun x => x.postName' <&> (· == p)) with
      | some post => pure [post.contents.titleString]
      | _ => failure
    | _ => failure
